import { Injectable, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';

@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  constructor() {
    // Strip sslmode from the connection string — we pass ssl config directly
    // to avoid pg's broken sslmode=require behavior in newer versions
    const url = new URL(process.env.DATABASE_URL ?? '');
    for (const key of ['sslmode', 'uselibpqcompat', 'connect_timeout']) {
      url.searchParams.delete(key);
    }
    const connStr = url.toString();
    const pool = new Pool({
      connectionString: connStr,
      ssl: { rejectUnauthorized: false },
    });
    const adapter = new PrismaPg(pool);
    super({ adapter });
  }

  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
