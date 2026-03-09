import { registerAs } from '@nestjs/config';
import type { TypeOrmModuleOptions } from '@nestjs/typeorm';

export default registerAs(
  'database',
  (): TypeOrmModuleOptions => {
    const databaseUrl = process.env.DATABASE_URL;

    if (databaseUrl) {
      return {
        type: 'postgres',
        url: databaseUrl,
        autoLoadEntities: true,
        synchronize: process.env.DB_SYNCHRONIZE === 'true',
        logging: process.env.NODE_ENV !== 'production',
        migrations: ['dist/database/migrations/*.js'],
        migrationsRun: false,
        ssl: false,
      };
    }

    return {
      type: 'postgres',
      host: process.env.DB_HOST ?? 'localhost',
      port: parseInt(process.env.DB_PORT ?? '5432', 10),
      database: process.env.DB_NAME ?? 'invlog',
      username: process.env.DB_USER ?? 'postgres',
      password: process.env.DB_PASSWORD ?? '',
      autoLoadEntities: true,
      synchronize: process.env.NODE_ENV !== 'production',
      logging: process.env.NODE_ENV !== 'production',
      migrations: ['dist/database/migrations/*.js'],
      migrationsRun: false,
    };
  },
);
