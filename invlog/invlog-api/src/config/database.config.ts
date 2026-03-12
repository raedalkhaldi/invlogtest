import { registerAs } from '@nestjs/config';
import type { TypeOrmModuleOptions } from '@nestjs/typeorm';

const isProduction = process.env.NODE_ENV === 'production';

const poolConfig = {
  extra: {
    // Connection pool settings
    max: isProduction ? 50 : 10,
    min: isProduction ? 5 : 1,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 5000,
    application_name: 'invlog-api',
  },
};

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
        logging: !isProduction,
        migrations: ['dist/database/migrations/*.js'],
        migrationsRun: false,
        ssl: false,
        ...poolConfig,
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
      synchronize: !isProduction,
      logging: !isProduction,
      migrations: ['dist/database/migrations/*.js'],
      migrationsRun: false,
      ...poolConfig,
    };
  },
);
