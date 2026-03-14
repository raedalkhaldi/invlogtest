import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In, MoreThan } from 'typeorm';
import { Story, StoryView } from './entities/story.entity';
import { PostMedia } from '../posts/entities/post.entity';
import { User } from '../users/entities/user.entity';
import { FollowsService } from '../follows/follows.service';

export interface StoryGroup {
  user: Partial<User>;
  stories: Story[];
  hasUnviewed: boolean;
  latestAt: Date;
}

@Injectable()
export class StoriesService {
  constructor(
    @InjectRepository(Story)
    private readonly storyRepo: Repository<Story>,
    @InjectRepository(StoryView)
    private readonly storyViewRepo: Repository<StoryView>,
    @InjectRepository(PostMedia)
    private readonly mediaRepo: Repository<PostMedia>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    private readonly followsService: FollowsService,
  ) {}

  async create(userId: string, mediaId: string): Promise<Story> {
    const media = await this.mediaRepo.findOne({
      where: { id: mediaId, uploaderId: userId },
    });
    if (!media) throw new BadRequestException('Media not found or not owned');

    // Wait for media processing to complete (polls every 2s, up to 120s)
    const readyMedia = await this.waitForProcessing(media.id);

    const story = this.storyRepo.create({
      authorId: userId,
      mediaType: readyMedia.mediaType,
      url: readyMedia.url,
      thumbnailUrl: readyMedia.thumbnailUrl,
      blurhash: readyMedia.blurhash,
      durationSecs: readyMedia.durationSecs,
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 hours
    });

    return this.storyRepo.save(story);
  }

  private async waitForProcessing(
    mediaId: string,
    maxWaitMs = 120_000,
    intervalMs = 2_000,
  ): Promise<PostMedia> {
    const start = Date.now();
    while (Date.now() - start < maxWaitMs) {
      const media = await this.mediaRepo.findOne({ where: { id: mediaId } });
      if (!media) throw new BadRequestException('Media not found');
      if (media.processingStatus === 'ready') return media;
      if (media.processingStatus === 'failed') {
        throw new BadRequestException('Media processing failed');
      }
      await new Promise((r) => setTimeout(r, intervalMs));
    }
    throw new BadRequestException('Media processing timed out');
  }

  async getFeed(userId: string): Promise<StoryGroup[]> {
    const followedIds = await this.followsService.getFollowedUserIds(userId);
    const authorIds = [...followedIds, userId];

    // Fetch active stories (not expired)
    const stories = await this.storyRepo.find({
      where: {
        authorId: In(authorIds),
        expiresAt: MoreThan(new Date()),
      },
      order: { createdAt: 'ASC' },
    });

    if (!stories.length) return [];

    // Batch-fetch authors
    const uniqueAuthorIds = [...new Set(stories.map((s) => s.authorId))];
    const authors = await this.userRepo
      .createQueryBuilder('u')
      .select([
        'u.id',
        'u.username',
        'u.displayName',
        'u.avatarUrl',
        'u.isVerified',
      ])
      .where('u.id IN (:...ids)', { ids: uniqueAuthorIds })
      .getMany();
    const authorMap = new Map(authors.map((a) => [a.id, a]));

    // Batch-fetch views by this user
    const storyIds = stories.map((s) => s.id);
    const views = await this.storyViewRepo.find({
      where: { userId, storyId: In(storyIds) },
      select: ['storyId'],
    });
    const viewedSet = new Set(views.map((v) => v.storyId));

    // Mark viewed status
    for (const story of stories) {
      story.author = authorMap.get(story.authorId);
      story.isViewedByMe = viewedSet.has(story.id);
    }

    // Group by author
    const groupMap = new Map<string, Story[]>();
    for (const story of stories) {
      const list = groupMap.get(story.authorId) ?? [];
      list.push(story);
      groupMap.set(story.authorId, list);
    }

    const groups: StoryGroup[] = [];
    for (const [authorId, authorStories] of groupMap) {
      const user = authorMap.get(authorId);
      if (!user) continue;

      groups.push({
        user,
        stories: authorStories,
        hasUnviewed: authorStories.some((s) => !s.isViewedByMe),
        latestAt: authorStories[authorStories.length - 1].createdAt,
      });
    }

    // Sort: current user first, then unviewed groups first, then by recency
    groups.sort((a, b) => {
      if (a.user.id === userId) return -1;
      if (b.user.id === userId) return 1;
      if (a.hasUnviewed !== b.hasUnviewed) return a.hasUnviewed ? -1 : 1;
      return b.latestAt.getTime() - a.latestAt.getTime();
    });

    return groups;
  }

  async markViewed(userId: string, storyId: string): Promise<void> {
    const story = await this.storyRepo.findOne({ where: { id: storyId } });
    if (!story) throw new NotFoundException('Story not found');

    const existing = await this.storyViewRepo.findOne({
      where: { storyId, userId },
    });
    if (existing) return; // Already viewed

    const view = this.storyViewRepo.create({ storyId, userId });
    await this.storyViewRepo.save(view);

    // Increment view count
    await this.storyRepo
      .createQueryBuilder()
      .update(Story)
      .set({ viewCount: () => '"view_count" + 1' })
      .where('id = :id', { id: storyId })
      .execute();
  }

  async getViewers(
    userId: string,
    storyId: string,
  ): Promise<Partial<User>[]> {
    const story = await this.storyRepo.findOne({ where: { id: storyId } });
    if (!story) throw new NotFoundException('Story not found');
    if (story.authorId !== userId) {
      throw new ForbiddenException('Only the author can view story viewers');
    }

    const views = await this.storyViewRepo.find({
      where: { storyId },
      order: { createdAt: 'DESC' },
    });

    if (!views.length) return [];

    const userIds = views.map((v) => v.userId);
    const users = await this.userRepo
      .createQueryBuilder('u')
      .select([
        'u.id',
        'u.username',
        'u.displayName',
        'u.avatarUrl',
        'u.isVerified',
      ])
      .where('u.id IN (:...ids)', { ids: userIds })
      .getMany();

    return users;
  }

  async deleteStory(userId: string, storyId: string): Promise<void> {
    const story = await this.storyRepo.findOne({ where: { id: storyId } });
    if (!story) throw new NotFoundException('Story not found');
    if (story.authorId !== userId) {
      throw new ForbiddenException('Not your story');
    }

    await this.storyRepo.delete(storyId);
  }
}
