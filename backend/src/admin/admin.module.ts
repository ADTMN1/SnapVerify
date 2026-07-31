import { Module } from '@nestjs/common';
import { AdminAuthModule } from './admin-auth.module';
import { AdminDashboardModule } from './admin-dashboard.module';

@Module({
  imports: [AdminAuthModule, AdminDashboardModule],
  exports: [AdminAuthModule, AdminDashboardModule],
})
export class AdminModule {}
