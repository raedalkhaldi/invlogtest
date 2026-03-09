import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  S3Client,
  HeadBucketCommand,
  CreateBucketCommand,
  PutBucketPolicyCommand,
  PutObjectCommand,
  GetObjectCommand,
  HeadObjectCommand,
  DeleteObjectCommand,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import type { StorageConfig } from '../../config/storage.config';

@Injectable()
export class StorageService implements OnModuleInit {
  private readonly logger = new Logger(StorageService.name);
  private readonly s3: S3Client;
  private readonly bucket: string;
  private readonly mediaBaseUrl: string;

  constructor(private readonly configService: ConfigService) {
    const config = this.configService.get<StorageConfig>('storage')!;
    this.bucket = config.bucket;
    this.mediaBaseUrl = config.mediaBaseUrl;

    this.s3 = new S3Client({
      endpoint: config.endpoint,
      region: config.region,
      credentials: {
        accessKeyId: config.accessKey,
        secretAccessKey: config.secretKey,
      },
      forcePathStyle: config.usePathStyle,
    });
  }

  async onModuleInit(): Promise<void> {
    await this.ensureBucket();
  }

  private async ensureBucket(): Promise<void> {
    try {
      await this.s3.send(new HeadBucketCommand({ Bucket: this.bucket }));
      this.logger.log(`Bucket "${this.bucket}" already exists`);
    } catch (err: any) {
      if (
        err.name === 'NotFound' ||
        err.name === 'NoSuchBucket' ||
        err.$metadata?.httpStatusCode === 404
      ) {
        this.logger.log(`Creating bucket "${this.bucket}"...`);
        await this.s3.send(new CreateBucketCommand({ Bucket: this.bucket }));

        // Set public-read policy for local dev
        const policy = {
          Version: '2012-10-17',
          Statement: [
            {
              Sid: 'PublicRead',
              Effect: 'Allow',
              Principal: '*',
              Action: ['s3:GetObject'],
              Resource: [`arn:aws:s3:::${this.bucket}/*`],
            },
          ],
        };

        await this.s3.send(
          new PutBucketPolicyCommand({
            Bucket: this.bucket,
            Policy: JSON.stringify(policy),
          }),
        );

        this.logger.log(`Bucket "${this.bucket}" created with public-read policy`);
      } else {
        this.logger.error('Failed to check/create bucket', err);
        throw err;
      }
    }
  }

  async generatePresignedPutUrl(
    key: string,
    contentType: string,
    maxSizeBytes: number,
  ): Promise<string> {
    const command = new PutObjectCommand({
      Bucket: this.bucket,
      Key: key,
      ContentType: contentType,
      ContentLength: maxSizeBytes,
    });

    return getSignedUrl(this.s3, command, { expiresIn: 300 }); // 5 minutes
  }

  async headObject(key: string): Promise<boolean> {
    try {
      await this.s3.send(
        new HeadObjectCommand({ Bucket: this.bucket, Key: key }),
      );
      return true;
    } catch {
      return false;
    }
  }

  async getObjectBuffer(key: string): Promise<Buffer> {
    const response = await this.s3.send(
      new GetObjectCommand({ Bucket: this.bucket, Key: key }),
    );

    const stream = response.Body;
    if (!stream) {
      throw new Error(`Empty body for key: ${key}`);
    }

    // Collect stream into buffer
    const chunks: Uint8Array[] = [];
    for await (const chunk of stream as AsyncIterable<Uint8Array>) {
      chunks.push(chunk);
    }
    return Buffer.concat(chunks);
  }

  async putObject(
    key: string,
    body: Buffer,
    contentType: string,
  ): Promise<void> {
    await this.s3.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: body,
        ContentType: contentType,
      }),
    );
  }

  async deleteObject(key: string): Promise<void> {
    await this.s3.send(
      new DeleteObjectCommand({ Bucket: this.bucket, Key: key }),
    );
  }

  getPublicUrl(key: string): string {
    return `${this.mediaBaseUrl}/${key}`;
  }
}
