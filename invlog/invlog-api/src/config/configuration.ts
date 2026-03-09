export interface AppConfig {
  app: {
    port: number;
    prefix: string;
    nodeEnv: string;
  };
  database: {
    host: string;
    port: number;
    name: string;
    user: string;
    password: string;
  };
  redis: {
    host: string;
    port: number;
  };
  jwt: {
    accessSecret: string;
    accessExpiry: string;
    refreshSecret: string;
    refreshExpiry: string;
  };
}

export default (): AppConfig => ({
  app: {
    port: parseInt(process.env.PORT ?? process.env.APP_PORT ?? '3000', 10),
    prefix: process.env.API_PREFIX ?? process.env.APP_PREFIX ?? 'api/v1',
    nodeEnv: process.env.NODE_ENV ?? 'development',
  },
  database: {
    host: process.env.DB_HOST ?? 'localhost',
    port: parseInt(process.env.DB_PORT ?? '5432', 10),
    name: process.env.DB_NAME ?? 'invlog',
    user: process.env.DB_USER ?? 'postgres',
    password: process.env.DB_PASSWORD ?? '',
  },
  redis: {
    host: process.env.REDIS_HOST ?? 'localhost',
    port: parseInt(process.env.REDIS_PORT ?? '6379', 10),
  },
  jwt: {
    accessSecret: process.env.JWT_ACCESS_SECRET ?? 'access-secret-change-me',
    accessExpiry: process.env.JWT_ACCESS_EXPIRY ?? '15m',
    refreshSecret: process.env.JWT_REFRESH_SECRET ?? 'refresh-secret-change-me',
    refreshExpiry: process.env.JWT_REFRESH_EXPIRY ?? '7d',
  },
});
