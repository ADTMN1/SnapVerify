import { Module } from '@nestjs/common';
import { AdminAuthModule } from './admin-auth.module';
import { PlatformAdminService } from './services/platform-admin.service';
import { PlatformAdminController } from './controllers/platform-admin.controller';

@Module({
  imports: [AdminAuthModule],
  providers: [PlatformAdminService],
  controllers: [PlatformAdminController],
  exports: [PlatformAdminService],
})
export class PlatformAdminModule {}
