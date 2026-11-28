import {
  BadRequestException,
  ForbiddenException,
  GoneException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PaymentProvider, Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { maskAccountNumberForResponse } from '../payment/account-mask';
import {
  QR_VERSION,
  QrOriginRequest,
  buildQrUrl,
  resolveQrBaseUrl,
} from './qr-link';
import { isValidPublicId } from './public-id';
import { PaymentQrService } from './payment-qr/payment-qr.service';

/**
 * Caller context for QR operations. Populated from the verified JWT by
 * QrController; never from client-supplied query parameters.
 */
export interface QrAccessContext {
  organizationId: string;
  role: Role;
  /** Branch the caller is scoped to. Null/undefined for OWNER. */
  branchId?: string | null;
  userId?: string;
  ipAddress?: string;
}

export interface ListQrQuery {
  branchId?: string;
  provider?: string;
  /** Raw query value; coerced in the service so the DTO stays a plain string. */
  isActive?: string;
  search?: string;
}

/** Audit actions recorded for sensitive QR access. */
export const QR_AUDIT_ACTIONS = {
  LIST_VIEWED: 'QR_LIST_VIEWED',
  ACCOUNT_VIEWED: 'QR_ACCOUNT_VIEWED',
  RESOLVED: 'QR_RESOLVED',
} as const;

/**
 * QR code domain service.
 *
 * Security model:
 *   - Every query is scoped by organizationId taken from the verified token,
 *     so an account can never be read through another tenant.
 *   - Callers scoped to a branch (MANAGER/CASHIER/WAITER) only ever see
 *     accounts of their own branch; org-wide accounts (branchId = null) are
 *     not visible to them.
 *   - Account numbers are only ever returned masked (shared helper with
 *     PaymentAccountService). QR payloads contain the opaque public id only.
 *   - Resolving an identifier for another tenant returns 404 (existence is not
 *     disclosed); a disabled account returns 410.
 *   - QR access is written to the activity log. Audit writes are best-effort:
 *     a failed audit write must not take the read path down, so the failure is
 *     logged and swallowed.
 */
@Injectable()
export class QrService {
  private readonly logger = new Logger(QrService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
    private readonly paymentQrService: PaymentQrService,
  ) {}

  // ── List ──────────────────────────────────────────────────────────────────

  async listForBusiness(
    ctx: QrAccessContext,
    query: ListQrQuery = {},
    req?: QrOriginRequest,
  ) {
    const branchScope = this.resolveBranchScope(ctx, query.branchId);
    const providerFilter = this.parseProvider(query.provider);
    const isActiveFilter = this.parseBoolean(query.isActive);
    const search = query.search?.trim();

    const or: Record<string, unknown>[] = [];
    if (search) {
      or.push({ publicId: { contains: search, mode: 'insensitive' } });
      or.push({
        accountHolderName: { contains: search, mode: 'insensitive' },
      });
      or.push({
        branch: { name: { contains: search, mode: 'insensitive' } },
      });
      const providerMatches = Object.values(PaymentProvider).filter((p) =>
        p.toLowerCase().includes(search.toLowerCase()),
      );
      if (providerMatches.length > 0) {
        or.push({ provider: { in: providerMatches } });
      }
    }

    const accounts = await this.prisma.paymentAccount.findMany({
      where: {
        organizationId: ctx.organizationId,
        ...(branchScope ? { branchId: branchScope } : {}),
        ...(providerFilter ? { provider: providerFilter } : {}),
        ...(isActiveFilter !== undefined ? { isActive: isActiveFilter } : {}),
        ...(or.length > 0 ? { OR: or } : {}),
      },
      include: {
        branch: { select: { id: true, name: true } },
        organization: { select: { id: true, name: true } },
      },
      orderBy: [{ provider: 'asc' }, { createdAt: 'asc' }],
    });

    const baseUrl = resolveQrBaseUrl(this.config, req);
    await this.audit(ctx, QR_AUDIT_ACTIONS.LIST_VIEWED, {
      count: accounts.length,
    });

    return {
      qrVersion: QR_VERSION,
      items: accounts.map((account) => this.toAccountView(account, baseUrl)),
    };
  }

  // ── Single account ────────────────────────────────────────────────────────

  async getAccountQr(
    ctx: QrAccessContext,
    accountId: string,
    req?: QrOriginRequest,
  ) {
    if (!accountId) {
      throw new BadRequestException('A payment account id is required.');
    }

    const account = await this.prisma.paymentAccount.findFirst({
      where: { id: accountId, organizationId: ctx.organizationId },
      include: {
        branch: { select: { id: true, name: true } },
        organization: { select: { id: true, name: true } },
      },
    });

    if (!account) {
      throw new NotFoundException('Payment account not found.');
    }
    this.assertBranchAccess(ctx, account.branchId);

    const baseUrl = resolveQrBaseUrl(this.config, req);
    await this.audit(ctx, QR_AUDIT_ACTIONS.ACCOUNT_VIEWED, {
      paymentAccountId: account.id,
    });

    return this.toAccountView(account, baseUrl);
  }

  // ── Resolve a scanned identifier ──────────────────────────────────────────

  async resolve(publicId: string, ctx: QrAccessContext, req?: QrOriginRequest) {
    if (!isValidPublicId(publicId)) {
      throw new BadRequestException('This is not a valid SnapVerify QR code.');
    }

    const account = await this.prisma.paymentAccount.findUnique({
      where: { publicId },
      include: {
        branch: { select: { id: true, name: true } },
        organization: { select: { id: true, name: true } },
      },
    });

    // Cross-tenant identifiers are indistinguishable from unknown ones: no
    // existence or ownership information is disclosed.
    if (!account || account.organizationId !== ctx.organizationId) {
      throw new NotFoundException(
        'This QR code is not registered to any payment account you can access.',
      );
    }

    this.assertBranchAccess(ctx, account.branchId);

    if (!account.isActive) {
      await this.audit(ctx, QR_AUDIT_ACTIONS.RESOLVED, {
        paymentAccountId: account.id,
        outcome: 'DISABLED',
      });
      throw new GoneException(
        'This payment account is no longer active, so its QR code cannot be used.',
      );
    }

    const baseUrl = resolveQrBaseUrl(this.config, req);
    await this.audit(ctx, QR_AUDIT_ACTIONS.RESOLVED, {
      paymentAccountId: account.id,
      outcome: 'OK',
    });

    return {
      ...this.toAccountView(account, baseUrl),
      /**
       * Resolving identifies the receiving account only. It is explicitly not
       * payment confirmation; payment verification happens through the
       * dedicated verification endpoints.
       */
      confirmedPayment: false,
      notice:
        'This identifies a payment account. It is not proof of payment — verify the transaction reference before releasing goods or services.',
    };
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  private toAccountView(
    account: {
      id: string;
      publicId: string;
      organizationId: string;
      provider: PaymentProvider;
      accountNumber: string | null;
      suffix: string | null;
      accountHolderName: string | null;
      isActive: boolean;
      createdAt: Date;
      branchId: string | null;
      branch?: { id: string; name: string } | null;
      organization?: { id: string; name: string } | null;
    },
    baseUrl: string | null,
  ) {
    const bankPaymentQr = this.paymentQrService.generate({
      provider: account.provider,
      // Use the stored account data available to the backend only. The full
      // account number is never exposed in the API response below.
      accountNumber: account.accountNumber,
      accountHolderName: account.accountHolderName,
      suffix: account.suffix,
    });

    return {
      id: account.id,
      publicId: account.publicId,
      provider: account.provider,
      // Masked only — the raw account number never leaves the server.
      accountNumber: maskAccountNumberForResponse(account.accountNumber),
      accountHolderName: account.accountHolderName,
      suffix: account.suffix,
      isActive: account.isActive,
      qrVersion: QR_VERSION,
      /**
       * Legacy field name retained for client compatibility. When a verified
       * bank-payment payload exists it is the exact payload to encode in the QR
       * image (never a SnapVerify URL). When unsupported this is null so clients
       * must not render a fake/bank-incompatible payment QR.
       */
      qrUrl: bankPaymentQr.supported ? bankPaymentQr.payload : null,
      bankPaymentQr,
      /**
       * Internal SnapVerify account identifier link used only by SnapVerify's
       * own resolve flow. It is NOT a bank/payment QR payload and must never be
       * presented as a scannable bank payment code.
       */
      internalQrUrl: baseUrl ? buildQrUrl(baseUrl, account.publicId) : null,
      branch: account.branch
        ? { id: account.branch.id, name: account.branch.name }
        : null,
      organization: account.organization
        ? { id: account.organization.id, name: account.organization.name }
        : { id: account.organizationId, name: null },
      createdAt: account.createdAt,
    };
  }

  /**
   * Owners may read any branch of their organization. Everyone else is
   * constrained to their assigned branch. A caller without a branch assignment
   * is denied outright rather than silently widened to the whole org.
   */
  private resolveBranchScope(
    ctx: QrAccessContext,
    requestedBranchId?: string,
  ): string | null {
    if (ctx.role === Role.OWNER) {
      return requestedBranchId ?? null;
    }

    if (!ctx.branchId) {
      throw new ForbiddenException(
        'You must be assigned to a branch to access QR codes.',
      );
    }
    if (requestedBranchId && requestedBranchId !== ctx.branchId) {
      throw new ForbiddenException('You can only access your assigned branch.');
    }
    return ctx.branchId;
  }

  private assertBranchAccess(
    ctx: QrAccessContext,
    accountBranchId: string | null,
  ): void {
    if (ctx.role === Role.OWNER) return;

    if (!ctx.branchId) {
      throw new ForbiddenException(
        'You must be assigned to a branch to access QR codes.',
      );
    }

    // Org-wide accounts (no branch) are not readable by branch-scoped roles.
    if (accountBranchId !== ctx.branchId) {
      throw new ForbiddenException(
        'This payment account belongs to another branch.',
      );
    }
  }

  private parseProvider(raw?: string): PaymentProvider | null {
    if (!raw) return null;
    const value = raw.trim().toUpperCase();
    if (!value) return null;
    const match = (Object.values(PaymentProvider) as string[]).find(
      (p) => p === value,
    );
    if (!match) {
      throw new BadRequestException(`Unknown payment provider: ${raw}`);
    }
    return match as PaymentProvider;
  }

  private parseBoolean(raw?: string): boolean | undefined {
    if (raw === undefined || raw === '') return undefined;
    if (raw === 'true') return true;
    if (raw === 'false') return false;
    throw new BadRequestException('isActive must be "true" or "false".');
  }

  /**
   * Record QR access. Metadata intentionally contains identifiers only —
   * never the QR payload, account number or holder details.
   */
  private async audit(
    ctx: QrAccessContext,
    action: string,
    metadata: Record<string, unknown>,
  ): Promise<void> {
    try {
      await this.prisma.activityLog.create({
        data: {
          organizationId: ctx.organizationId,
          userId: ctx.userId ?? null,
          action,
          metadata: { ...metadata, role: ctx.role },
          ipAddress: ctx.ipAddress ?? null,
        },
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      this.logger.warn(`[audit] failed to record ${action}: ${message}`);
    }
  }
}
