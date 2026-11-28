import { Module } from '@nestjs/common';
import { AdminAuthModule } from './admin-auth.module';
import { AdminDashboardModule } from './admin-dashboard.module';
import { PlatformAdminModule } from './platform-admin.module';

@Module({
  imports: [AdminAuthModule, AdminDashboardModule, PlatformAdminModule],
  exports: [AdminAuthModule, AdminDashboardModule, PlatformAdminModule],
})
export class AdminModule {}
