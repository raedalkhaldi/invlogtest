import { registerAs } from '@nestjs/config';

export interface StorageConfig {
  endpoint: string;
  accessKey: string;
  secretKey: string;
  bucket: string;
  region: string;
  usePathStyle: boolean;
  mediaBaseUrl: string;
}

export default registerAs(
  'storage',
  (): StorageConfig => ({
    endpoint: process.env.S3_ENDPOINT ?? 'http://localhost:9000',
    accessKey: process.env.S3_ACCESS_KEY ?? 'minioadmin',
    secretKey: process.env.S3_SECRET_KEY ?? 'minioadmin',
    bucket: process.env.S3_BUCKET ?? 'invlog-media',
    region: process.env.S3_REGION ?? 'us-east-1',
    usePathStyle: process.env.S3_USE_PATH_STYLE !== 'false',
    mediaBaseUrl:
      process.env.MEDIA_BASE_URL ?? 'http://localhost:9000/invlog-media',
  }),
);
