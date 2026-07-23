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

@Injectable()
export class PaymentAccountService {
  private readonly logger = new Logger(PaymentAccountService.name);

  constructor(private prisma: PrismaService) {}

  // Create a payment account
  async create(organizationId: string, dto: CreatePaymentAccountDto) {
    this.logger.log(
      `[create] Creating payment account for org: ${organizationId}, provider: ${dto.provider}`,
    );

    // Validate suffix length for specific providers
    if (dto.provider === PaymentProvider.CBE) {
      if (!dto.suffix || dto.suffix.length !== 8) {
        throw new BadRequestException(
          'CBE payment account requires an 8-digit suffix',
        );
      }
    }
    if (dto.provider === PaymentProvider.ABYSSINIA) {
      if (!dto.suffix || dto.suffix.length !== 5) {
        throw new BadRequestException(
          'Abyssinia payment account requires a 5-digit suffix',
        );
      }
    }

    try {
      const account = await this.prisma.paymentAccount.upsert({
        where: {
          organizationId_provider_branchId: {
            organizationId,
            provider: dto.provider,
            branchId: dto.branchId || null,
          } as any, // Type assertion because Prisma's unique constraint types can be tricky
        },
        update: {
          accountNumber: dto.accountNumber,
          suffix: dto.suffix,
          accountHolderName: dto.accountHolderName,
          isActive: true,
        },
        create: {
          organizationId,
          provider: dto.provider,
          accountNumber: dto.accountNumber,
          suffix: dto.suffix,
          accountHolderName: dto.accountHolderName,
          branchId: dto.branchId || null,
        },
      });
      this.logger.log(
        `[create] Payment account created/updated: ${account.id}`,
      );
      return account;
    } catch (err: any) {
      this.logger.error(`[create] DB error: ${err?.message ?? String(err)}`);
      throw new BadRequestException('Failed to create payment account');
    }
  }

  // Get all payment accounts for an organization
  async findAll(organizationId: string) {
    return this.prisma.paymentAccount.findMany({
      where: { organizationId },
      orderBy: { createdAt: 'desc' },
      include: {
        branch: true,
      },
    });
  }

  // Get payment accounts by organization and optionally branch
  async findByOrganizationAndBranch(organizationId: string, branchId?: string) {
    return this.prisma.paymentAccount.findMany({
      where: {
        organizationId,
        branchId: branchId ?? undefined,
        isActive: true,
      },
      include: {
        branch: true,
      },
    });
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
      throw new NotFoundException(`Payment account for ${provider} not found`);
    }
    return account;
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
          'CBE payment account requires an 8-digit suffix',
        );
      }
    }
    if (provider === PaymentProvider.ABYSSINIA && dto.suffix) {
      if (dto.suffix.length !== 5) {
        throw new BadRequestException(
          'Abyssinia payment account requires a 5-digit suffix',
        );
      }
    }

    const account = await this.prisma.paymentAccount.updateMany({
      where: {
        organizationId,
        provider,
        branchId: branchId ?? undefined,
      },
      data: dto,
    });
    if (account.count === 0) {
      throw new NotFoundException(`Payment account for ${provider} not found`);
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
    return updatedAccount!;
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
      throw new NotFoundException(`Payment account for ${provider} not found`);
    }
    return { message: 'Payment account deleted successfully' };
  }
}
