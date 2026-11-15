import {
  Injectable,
  NotFoundException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreatePaymentAccountDto } from './dto/create-payment-account.dto';
import { UpdatePaymentAccountDto } from './dto/update-payment-account.dto';
import { PaymentProvider } from '@prisma/client';
import { ConfigService } from '@nestjs/config';
import { computeAccountNumberHash } from './account-hash';
import { maskAccount } from './account-mask';
import { generatePublicId, isUniqueConstraintViolation } from '../qr/public-id';

/**
 * Number of attempts to allocate a unique public QR identifier. A collision
 * on 96 random bits is practically impossible; the retry exists so a
 * collision can never surface as a failed account creation.
 */
const PUBLIC_ID_ATTEMPTS = 5;

@Injectable()
export class PaymentAccountService {
  private readonly logger = new Logger(PaymentAccountService.name);
  private readonly accountHashSecret: string;

  constructor(
    private prisma: PrismaService,
    private config: ConfigService,
  ) {
    // Stage 1 review fix: hashes are keyed HMAC-SHA-256. Writing an account
    // without a usable secret would produce hashes matching cannot verify,
    // so fail loudly rather than store a weak hash.
    const secret = this.config.get<string>('ACCOUNT_HASH_SECRET', '');
    if (!secret || secret.length < 32) {
      throw new Error(
        'FATAL: ACCOUNT_HASH_SECRET is missing or too short (>= 32 chars required). Generate one with: openssl rand -base64 48',
      );
    }
    this.accountHashSecret = secret;
  }

  private hashAccountNumber(
    accountNumber: string | null | undefined,
  ): string | null {
    return computeAccountNumberHash(accountNumber, this.accountHashSecret);
  }

  // Create a payment account
  async create(organizationId: string, dto: CreatePaymentAccountDto) {
    this.logger.log(
      `[create] Creating payment account for org: ${organizationId}, provider: ${dto.provider}`,
    );

    // Validate suffix length for specific providers
    if (dto.provider === PaymentProvider.CBE) {
      if (!dto.suffix || dto.suffix.length !== 8) {
        throw new BadRequestException(
          'CBE accounts require an 8-digit account suffix.',
        );
      }
    }
    if (dto.provider === PaymentProvider.ABYSSINIA) {
      if (!dto.suffix || dto.suffix.length !== 5) {
        throw new BadRequestException(
          'Abyssinia accounts require a 5-digit account suffix.',
        );
      }
    }

    try {
      // Check if account already exists for this organization/provider/branch combination
      const existingAccount = await this.prisma.paymentAccount.findFirst({
        where: {
          organizationId,
          provider: dto.provider,
          branchId: dto.branchId || undefined,
        },
      });

      if (existingAccount) {
        // Update existing account. A public QR identifier is never rewritten
        // (printed codes stay valid); one is only allocated if a legacy row
        // somehow has none.
        const account = await this.prisma.paymentAccount.update({
          where: { id: existingAccount.id },
          data: {
            accountNumber: dto.accountNumber,
            // Stage 1: hash is stored alongside so matching can use hashed
            // comparison; plaintext column retained for legacy backfill.
            accountNumberHash: this.hashAccountNumber(dto.accountNumber),
            suffix: dto.suffix,
            accountHolderName: dto.accountHolderName,
            isActive: true,
            ...(existingAccount.publicId
              ? {}
              : { publicId: generatePublicId() }),
          },
        });
        this.logger.log(`[create] Payment account updated: ${account.id}`);
        return maskAccount(account);
      } else {
        // Create new account. Every account receives its QR identifier here,
        // in the same write, so an account can never exist without one.
        for (let attempt = 1; attempt <= PUBLIC_ID_ATTEMPTS; attempt++) {
          try {
            const account = await this.prisma.paymentAccount.create({
              data: {
                organizationId,
                publicId: generatePublicId(),
                provider: dto.provider,
                accountNumber: dto.accountNumber,
                accountNumberHash: this.hashAccountNumber(dto.accountNumber),
                suffix: dto.suffix,
                accountHolderName: dto.accountHolderName,
                branchId: dto.branchId,
              },
            });
            this.logger.log(`[create] Payment account created: ${account.id}`);
            return maskAccount(account);
          } catch (err) {
            const collision = isUniqueConstraintViolation(err, 'publicId');
            if (!collision || attempt === PUBLIC_ID_ATTEMPTS) throw err;
            this.logger.warn(
              `[create] publicId collision, retrying (${attempt}/${PUBLIC_ID_ATTEMPTS})`,
            );
          }
        }
        // Unreachable: the loop either returns or rethrows.
        throw new BadRequestException(
          'Failed to create payment account. Please try again.',
        );
      }
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : String(err);
      this.logger.error(`[create] DB error: ${errorMessage}`);
      throw new BadRequestException(
        'Failed to create payment account. Please try again.',
      );
    }
  }

  // Get all payment accounts for an organization
  async findAll(organizationId: string) {
    const accounts = await this.prisma.paymentAccount.findMany({
      where: { organizationId },
      orderBy: { createdAt: 'desc' },
      include: {
        branch: true,
      },
    });
    return accounts.map(maskAccount);
  }

  // Get payment accounts by organization and optionally branch
  async findByOrganizationAndBranch(organizationId: string, branchId?: string) {
    const accounts = await this.prisma.paymentAccount.findMany({
      where: {
        organizationId,
        branchId: branchId ?? undefined,
        isActive: true,
      },
      include: {
        branch: true,
      },
    });
    return accounts.map(maskAccount);
  }

  // Get a single payment account by provider and branch
  async findByProviderAndBranch(
    organizationId: string,
    provider: PaymentProvider,
    branchId?: string,
  ) {
    const account = await this.prisma.paymentAccount.findFirst({
      where: {
        organizationId,
        provider,
        branchId: branchId ?? undefined,
        isActive: true,
      },
    });
    if (!account) {
      throw new NotFoundException(
        'Payment account not found. Please check the details.',
      );
    }
    return maskAccount(account);
  }

  // Update a payment account
  async update(
    organizationId: string,
    provider: PaymentProvider,
    branchId: string | undefined,
    dto: UpdatePaymentAccountDto,
  ) {
    this.logger.log(
      `[update] Updating payment account for org: ${organizationId}, provider: ${provider}`,
    );

    // Validate suffix if provided
    if (provider === PaymentProvider.CBE && dto.suffix) {
      if (dto.suffix.length !== 8) {
        throw new BadRequestException(
          'CBE accounts require an 8-digit account suffix.',
        );
      }
    }
    if (provider === PaymentProvider.ABYSSINIA && dto.suffix) {
      if (dto.suffix.length !== 5) {
        throw new BadRequestException(
          'Abyssinia accounts require a 5-digit account suffix.',
        );
      }
    }

    const account = await this.prisma.paymentAccount.updateMany({
      where: {
        organizationId,
        provider,
        branchId: branchId ?? undefined,
      },
      data: {
        ...dto,
        // Stage 1: keep the hash in sync when the account number changes.
        ...(dto.accountNumber !== undefined
          ? { accountNumberHash: this.hashAccountNumber(dto.accountNumber) }
          : {}),
      },
    });
    if (account.count === 0) {
      throw new NotFoundException(
        'Payment account not found. Please check the details.',
      );
    }

    // Fetch the updated account
    const updatedAccount = await this.prisma.paymentAccount.findFirst({
      where: {
        organizationId,
        provider,
        branchId: branchId ?? undefined,
      },
    });
    this.logger.log(`[update] Payment account updated: ${updatedAccount!.id}`);
    return maskAccount(updatedAccount!);
  }

  // Delete a payment account
  async remove(
    organizationId: string,
    provider: PaymentProvider,
    branchId?: string,
  ) {
    this.logger.log(
      `[remove] Deleting payment account for org: ${organizationId}, provider: ${provider}`,
    );
    const deleted = await this.prisma.paymentAccount.deleteMany({
      where: {
        organizationId,
        provider,
        branchId: branchId ?? undefined,
      },
    });
    if (deleted.count === 0) {
      throw new NotFoundException(
        'Payment account not found. Please check the details.',
      );
    }
    return { message: 'Payment account deleted successfully' };
  }
}
