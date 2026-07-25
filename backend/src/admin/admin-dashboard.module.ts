import { Module } from '@nestjs/common';
import { AdminAuthModule } from './admin-auth.module';
import { AdminDashboardService } from './services/admin-dashboard.service';
import { AdminDashboardController } from './controllers/admin-dashboard.controller';
import { AdminDataService } from './services/admin-data.service';
import { AdminDataController } from './controllers/admin-data.controller';

@Module({
  imports: [AdminAuthModule],
  providers: [AdminDashboardService, AdminDataService],
  controllers: [AdminDashboardController, AdminDataController],
  exports: [AdminDashboardService, AdminDataService],
})
export class AdminDashboardModule {}
