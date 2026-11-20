import { Injectable } from '@nestjs/common';
import { PaymentStatus, Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

export type NotificationType =
  | 'payment_verified'
  | 'payment_failed'
  | 'payment_rejected'
  | 'payment_pending'
  | 'invitation_created'
  | 'invitation_revoked';

export interface NotificationItem {
  id: string;
  type: NotificationType;
  title: string;
  body: string;
  createdAt: string;
  read: boolean;
  entityId: string;
}

interface GetFeedParams {
  organizationId: string;
  userId: string;
  role: string;
}

/**
 * Notification feed derived from real activity (payments + staff invitations).
 *
 * There is no separate notifications table: the feed is computed from the
 * records that already represent user-relevant events. A per-user
 * `notificationsReadAt` watermark is used for read/unread state, so marking
 * all as read is a single column update and new events automatically become
 * unread.
 */
@Injectable()
export class NotificationsService {
  constructor(private readonly prisma: PrismaService) {}

  async getFeed({ organizationId, userId, role }: GetFeedParams) {
    const isPrivileged = role === Role.OWNER || role === Role.MANAGER;

    const [payments, invitations, user] = await Promise.all([
      this.prisma.payment.findMany({
        where: {
          organizationId,
          // Cashiers/waiters only see their own verification activity.
          ...(isPrivileged ? {} : { userId }),
        },
        orderBy: { createdAt: 'desc' },
        take: 20,
      }),
      isPrivileged
        ? this.prisma.invitation.findMany({
            where: { organizationId },
            orderBy: { createdAt: 'desc' },
            take: 10,
          })
        : Promise.resolve([]),
      this.prisma.user.findUnique({
        where: { id: userId },
        select: { notificationsReadAt: true },
      }),
    ]);

    const lastReadAt = user?.notificationsReadAt ?? null;

    const notifications = [
      ...payments.map((payment) => this.fromPayment(payment, lastReadAt)),
      ...invitations.map((invitation) =>
        this.fromInvitation(invitation, lastReadAt),
      ),
    ].sort((a, b) => b.createdAt.localeCompare(a.createdAt));

    return {
      notifications,
      unreadCount: notifications.filter((n) => !n.read).length,
      lastReadAt: lastReadAt?.toISOString() ?? null,
    };
  }

  async markAllRead(userId: string) {
    const lastReadAt = new Date();
    await this.prisma.user.update({
      where: { id: userId },
      data: { notificationsReadAt: lastReadAt },
    });
    return { success: true, lastReadAt: lastReadAt.toISOString() };
  }

  private fromPayment(payment: any, lastReadAt: Date | null): NotificationItem {
    const amount = Number(payment.amount);
    const parts = [`${payment.currency} ${amount.toFixed(2)}`];
    if (payment.transactionId) parts.push(payment.transactionId);
    if (payment.senderName) parts.push(payment.senderName);

    let type: NotificationType;
    let title: string;
    switch (payment.status as PaymentStatus) {
      case PaymentStatus.VERIFIED:
        type = 'payment_verified';
        title = 'Payment verified';
        break;
      case PaymentStatus.FAILED:
        type = 'payment_failed';
        title = 'Verification failed';
        break;
      case PaymentStatus.REJECTED:
        type = 'payment_rejected';
        title = 'Payment rejected';
        break;
      default:
        type = 'payment_pending';
        title = 'Verification pending';
    }

    return {
      id: `payment:${payment.id}`,
      type,
      title,
      body: parts.join(' · '),
      createdAt: payment.createdAt.toISOString(),
      read: lastReadAt != null && payment.createdAt <= lastReadAt,
      entityId: payment.id,
    };
  }

  private fromInvitation(
    invitation: any,
    lastReadAt: Date | null,
  ): NotificationItem {
    const revoked = invitation.status === 'REVOKED';
    return {
      id: `invitation:${invitation.id}`,
      type: revoked ? 'invitation_revoked' : 'invitation_created',
      title: revoked ? 'Staff invitation revoked' : 'Staff invitation created',
      body: `${invitation.fullName ?? invitation.username ?? 'Staff member'} · ${invitation.role}`,
      createdAt: invitation.createdAt.toISOString(),
      read: lastReadAt != null && invitation.createdAt <= lastReadAt,
      entityId: invitation.id,
    };
  }
}