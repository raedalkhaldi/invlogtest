#!/usr/bin/env npx ts-node
/**
 * API Contract Test Suite
 *
 * Validates that every API endpoint returns data in the exact shape
 * the iOS app expects. Catches type mismatches (string vs number),
 * missing fields, and wrapper issues before they reach TestFlight.
 *
 * Usage:
 *   npx ts-node scripts/api-contract-test.ts
 *   npx ts-node scripts/api-contract-test.ts --base-url http://localhost:3000/api/v1
 *
 * Environment:
 *   API_BASE_URL  - defaults to https://invlog-api.fly.dev/api/v1
 *   TEST_EMAIL    - defaults to sara@demo.invlog.app
 *   TEST_PASSWORD - defaults to demo1234
 */

const BASE_URL =
  process.argv.find((a) => a.startsWith('--base-url='))?.split('=')[1] ||
  process.env.API_BASE_URL ||
  'https://invlog-api.fly.dev/api/v1';

const TEST_EMAIL = process.env.TEST_EMAIL || 'sara@demo.invlog.app';
const TEST_PASSWORD = process.env.TEST_PASSWORD || 'demo1234';

// ── Helpers ─────────────────────────────────────────────────────────────────

let token = '';
let passed = 0;
let failed = 0;
const failures: string[] = [];

async function api(
  method: string,
  path: string,
  body?: any,
): Promise<{ status: number; json: any; raw: string }> {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
  };
  if (token) headers['Authorization'] = `Bearer ${token}`;

  const res = await fetch(`${BASE_URL}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  const raw = await res.text();
  let json: any = null;
  try {
    json = JSON.parse(raw);
  } catch {}

  return { status: res.status, json, raw };
}

// ── Type Validators ─────────────────────────────────────────────────────────
// Mirror what Swift's JSONDecoder expects. If a field is required in the iOS
// model (not Optional), a missing/null value or wrong type is a failure.

type FieldSpec = {
  type: 'string' | 'number' | 'boolean' | 'array' | 'object' | 'date';
  required: boolean;
  /** For nested objects, validate inner shape */
  shape?: Record<string, FieldSpec>;
  /** For arrays, validate each element */
  elementShape?: Record<string, FieldSpec>;
};

const f = (
  type: FieldSpec['type'],
  required = true,
  extra?: Partial<FieldSpec>,
): FieldSpec => ({ type, required, ...extra });

// ── iOS Model Schemas ───────────────────────────────────────────────────────

const UserSchema: Record<string, FieldSpec> = {
  id: f('string'),
  username: f('string'),
  displayName: f('string', false),
  bio: f('string', false),
  avatarUrl: f('string', false),
  coverUrl: f('string', false),
  isVerified: f('boolean'),
  isPrivate: f('boolean'),
  followerCount: f('number'),
  followingCount: f('number'),
  postCount: f('number'),
  email: f('string', false),
  isFollowedByMe: f('boolean', false),
};

const PostMediaSchema: Record<string, FieldSpec> = {
  id: f('string'),
  mediaType: f('string'),
  url: f('string'),
  mediumUrl: f('string', false),
  thumbnailUrl: f('string', false),
  width: f('number', false),
  height: f('number', false),
  durationSecs: f('number', false),
  sortOrder: f('number', false),
  blurhash: f('string', false),
  processingStatus: f('string', false),
};

const RestaurantSchema: Record<string, FieldSpec> = {
  id: f('string'),
  ownerId: f('string'),
  name: f('string'),
  slug: f('string'),
  description: f('string', false),
  cuisineType: f('array', false),
  phone: f('string', false),
  email: f('string', false),
  website: f('string', false),
  avatarUrl: f('string', false),
  coverUrl: f('string', false),
  latitude: f('number', false),
  longitude: f('number', false),
  addressLine1: f('string', false),
  city: f('string', false),
  state: f('string', false),
  country: f('string', false),
  postalCode: f('string', false),
  priceRange: f('number', false),
  avgRating: f('number'),       // CRITICAL: must be number, not string
  reviewCount: f('number'),
  followerCount: f('number'),
  checkinCount: f('number'),
  isVerified: f('boolean'),
  operatingHours: f('array', false),
  menuItems: f('array', false),
  isFollowedByMe: f('boolean', false),
  distance: f('number', false),
};

const PostSchema: Record<string, FieldSpec> = {
  id: f('string'),
  authorId: f('string'),
  author: f('object', false, { shape: UserSchema }),
  restaurantId: f('string', false),
  restaurant: f('object', false, { shape: RestaurantSchema }),
  content: f('string', false),
  rating: f('number', false),
  latitude: f('number', false),
  longitude: f('number', false),
  locationName: f('string', false),
  locationAddress: f('string', false),
  likeCount: f('number'),
  commentCount: f('number'),
  isPublic: f('boolean'),
  media: f('array', false, { elementShape: PostMediaSchema }),
  createdAt: f('date'),
  isLikedByMe: f('boolean', false),
};

const CommentSchema: Record<string, FieldSpec> = {
  id: f('string'),
  postId: f('string'),
  authorId: f('string'),
  author: f('object', false, { shape: UserSchema }),
  parentId: f('string', false),
  content: f('string'),
  likeCount: f('number'),
  createdAt: f('date'),
  isLikedByMe: f('boolean', false),
};

const CheckInSchema: Record<string, FieldSpec> = {
  id: f('string'),
  userId: f('string'),
  restaurantId: f('string'),
  restaurant: f('object', false, { shape: RestaurantSchema }),
  user: f('object', false, { shape: UserSchema }),
  postId: f('string', false),
  createdAt: f('date'),
};

const NotificationSchema: Record<string, FieldSpec> = {
  id: f('string'),
  recipientId: f('string'),
  actorId: f('string', false),
  actor: f('object', false, { shape: UserSchema }),
  type: f('string'),
  targetType: f('string', false),
  targetId: f('string', false),
  message: f('string', false),
  isRead: f('boolean'),
  createdAt: f('date'),
};

// ── Validation Engine ───────────────────────────────────────────────────────

function validateField(
  value: any,
  spec: FieldSpec,
  path: string,
): string[] {
  const errors: string[] = [];

  if (value === null || value === undefined) {
    if (spec.required) {
      errors.push(`${path}: required field is null/missing`);
    }
    return errors;
  }

  switch (spec.type) {
    case 'string':
      if (typeof value !== 'string') {
        errors.push(
          `${path}: expected string, got ${typeof value} (${JSON.stringify(value)})`,
        );
      }
      break;
    case 'number':
      if (typeof value !== 'number') {
        errors.push(
          `${path}: expected number, got ${typeof value} (${JSON.stringify(value)})`,
        );
      }
      break;
    case 'boolean':
      if (typeof value !== 'boolean') {
        errors.push(
          `${path}: expected boolean, got ${typeof value} (${JSON.stringify(value)})`,
        );
      }
      break;
    case 'date':
      if (typeof value !== 'string' || isNaN(Date.parse(value))) {
        errors.push(
          `${path}: expected ISO date string, got ${typeof value} (${JSON.stringify(value)})`,
        );
      }
      break;
    case 'array':
      if (!Array.isArray(value)) {
        errors.push(`${path}: expected array, got ${typeof value}`);
      } else if (spec.elementShape && value.length > 0) {
        const elErrors = validateObject(value[0], spec.elementShape, `${path}[0]`);
        errors.push(...elErrors);
      }
      break;
    case 'object':
      if (typeof value !== 'object' || Array.isArray(value)) {
        errors.push(`${path}: expected object, got ${typeof value}`);
      } else if (spec.shape) {
        const objErrors = validateObject(value, spec.shape, path);
        errors.push(...objErrors);
      }
      break;
  }

  return errors;
}

function validateObject(
  obj: any,
  schema: Record<string, FieldSpec>,
  prefix: string,
): string[] {
  const errors: string[] = [];
  for (const [key, spec] of Object.entries(schema)) {
    const fieldErrors = validateField(obj[key], spec, `${prefix}.${key}`);
    errors.push(...fieldErrors);
  }
  return errors;
}

function validateWrapped(
  json: any,
  innerSchema: Record<string, FieldSpec> | null,
  testName: string,
  opts: {
    isArray?: boolean;
    allowEmpty?: boolean;
  } = {},
): boolean {
  const errors: string[] = [];

  // 1. Must have top-level { data: ... }
  if (!json || typeof json !== 'object') {
    errors.push('Response is not an object');
  } else if (!('data' in json)) {
    errors.push('Missing top-level "data" field (APIResponse wrapper)');
  } else {
    const data = json.data;

    if (opts.isArray) {
      // iOS expects data to be an array
      if (!Array.isArray(data)) {
        errors.push(
          `Expected data to be an array, got ${typeof data} — ` +
            `this is likely the double-wrap bug (data is an object with data/total inside)`,
        );
        // Check for the exact double-wrap pattern
        if (data && typeof data === 'object' && 'data' in data && 'total' in data) {
          errors.push(
            'CONFIRMED DOUBLE-WRAP: data = { data: [...], total } — ' +
              'controller must return result.data, not the full object',
          );
        }
      } else if (!opts.allowEmpty && data.length === 0) {
        // Warn but don't fail — could be legitimate empty result
        console.log(`    ⚠ Array is empty (can't validate element shape)`);
      } else if (innerSchema && data.length > 0) {
        const elErrors = validateObject(data[0], innerSchema, 'data[0]');
        errors.push(...elErrors);
      }
    } else if (innerSchema) {
      // iOS expects data to be a single object
      if (typeof data !== 'object' || Array.isArray(data)) {
        errors.push(`Expected data to be an object, got ${typeof data}`);
      } else {
        const objErrors = validateObject(data, innerSchema, 'data');
        errors.push(...objErrors);
      }
    }
  }

  if (errors.length > 0) {
    console.log(`  ✗ ${testName}`);
    for (const e of errors) {
      console.log(`    → ${e}`);
    }
    failed++;
    failures.push(testName);
    return false;
  } else {
    console.log(`  ✓ ${testName}`);
    passed++;
    return true;
  }
}

function checkStatus(
  status: number,
  expected: number,
  testName: string,
): boolean {
  if (status !== expected) {
    console.log(`  ✗ ${testName} — HTTP ${status} (expected ${expected})`);
    failed++;
    failures.push(`${testName} (HTTP ${status})`);
    return false;
  }
  return true;
}

// ── Test Cases ──────────────────────────────────────────────────────────────

async function run() {
  console.log(`\n🔬 API Contract Tests`);
  console.log(`   Base URL: ${BASE_URL}`);
  console.log(`   Test user: ${TEST_EMAIL}\n`);

  // ── Auth ──────────────────────────────────────────────────────────────
  console.log('── Auth ──');
  {
    const { status, json } = await api('POST', '/auth/login', {
      email: TEST_EMAIL,
      password: TEST_PASSWORD,
    });
    if (!checkStatus(status, 200, 'POST /auth/login')) {
      console.log('  ✗ Cannot continue without auth token. Aborting.');
      return;
    }
    const tokenData = json?.data;
    if (
      !tokenData ||
      typeof tokenData.accessToken !== 'string' ||
      typeof tokenData.refreshToken !== 'string'
    ) {
      console.log(
        '  ✗ Login response missing accessToken/refreshToken',
      );
      failed++;
      return;
    }
    token = tokenData.accessToken;
    console.log(`  ✓ POST /auth/login — got token (${token.length} chars)`);
    passed++;
  }

  // ── Users ─────────────────────────────────────────────────────────────
  console.log('\n── Users ──');
  let currentUserId = '';
  {
    const { status, json } = await api('GET', '/users/me');
    if (checkStatus(status, 200, 'GET /users/me')) {
      validateWrapped(json, UserSchema, 'GET /users/me → User shape');
      currentUserId = json?.data?.id || '';
    }
  }
  {
    const { status, json } = await api('GET', '/users/foodie_sara');
    if (checkStatus(status, 200, 'GET /users/:username')) {
      validateWrapped(json, UserSchema, 'GET /users/:username → User shape');
    }
  }

  // ── Feed ──────────────────────────────────────────────────────────────
  // iOS uses FeedResponse { data: [Post], nextCursor: String? }
  // API returns { data: Post[], nextCursor } → interceptor wraps as { data: { data: [...], nextCursor }, meta }
  // iOS decodes as APIResponse<FeedResponse> — this is correct!
  const FeedResponseSchema: Record<string, FieldSpec> = {
    data: f('array', true, { elementShape: PostSchema }),
    nextCursor: f('string', false),
  };

  console.log('\n── Feed ──');
  let feedPostId = '';
  let feedRestaurantSlug = '';
  {
    const { status, json } = await api('GET', '/feed?limit=5');
    if (checkStatus(status, 200, 'GET /feed')) {
      validateWrapped(json, FeedResponseSchema, 'GET /feed → FeedResponse shape');
      const feedData = json?.data?.data;
      if (Array.isArray(feedData)) {
        feedPostId = feedData[0]?.id || '';
        feedRestaurantSlug = feedData.find((p: any) => p.restaurant)?.restaurant?.slug || '';
      }
    }
  }
  {
    const { status, json } = await api('GET', '/feed/explore?limit=5');
    if (checkStatus(status, 200, 'GET /feed/explore')) {
      validateWrapped(json, FeedResponseSchema, 'GET /feed/explore → FeedResponse shape');
    }
  }

  // ── Posts ──────────────────────────────────────────────────────────────
  console.log('\n── Posts ──');
  if (feedPostId) {
    const { status, json } = await api('GET', `/posts/${feedPostId}`);
    if (checkStatus(status, 200, 'GET /posts/:id')) {
      validateWrapped(json, PostSchema, 'GET /posts/:id → Post shape');
    }
  } else {
    console.log('  ⚠ Skipping GET /posts/:id — no post ID from feed');
  }

  // ── Comments ──────────────────────────────────────────────────────────
  console.log('\n── Comments ──');
  if (feedPostId) {
    const { status, json } = await api(
      'GET',
      `/posts/${feedPostId}/comments?page=1&perPage=20`,
    );
    if (checkStatus(status, 200, 'GET /posts/:id/comments')) {
      validateWrapped(
        json,
        CommentSchema,
        'GET /posts/:id/comments → [Comment] shape (with author)',
        { isArray: true, allowEmpty: true },
      );

      // Extra: if comments exist, verify author is hydrated
      const comments = json?.data;
      if (Array.isArray(comments) && comments.length > 0) {
        const first = comments[0];
        if (first.author && typeof first.author === 'object') {
          console.log('  ✓ Comment.author is hydrated');
          passed++;
        } else {
          console.log(
            '  ✗ Comment.author is null — author hydration not working',
          );
          failed++;
          failures.push('Comment.author hydration');
        }
      }
    }
  }

  // ── Search ────────────────────────────────────────────────────────────
  console.log('\n── Search ──');
  {
    // Search people — must have isFollowedByMe
    const { status, json } = await api('GET', '/search?type=people');
    if (checkStatus(status, 200, 'GET /search?type=people')) {
      const data = json?.data;
      if (data && typeof data === 'object' && 'users' in data) {
        const users = data.users;
        if (Array.isArray(users) && users.length > 0) {
          const userErrors = validateObject(users[0], UserSchema, 'search.users[0]');
          if (userErrors.length === 0) {
            console.log('  ✓ Search users → User shape');
            passed++;
          } else {
            console.log('  ✗ Search users shape errors:');
            userErrors.forEach((e) => console.log(`    → ${e}`));
            failed++;
            failures.push('Search users shape');
          }

          // Check isFollowedByMe specifically
          if ('isFollowedByMe' in users[0] && typeof users[0].isFollowedByMe === 'boolean') {
            console.log('  ✓ Search users have isFollowedByMe (boolean)');
            passed++;
          } else {
            console.log(
              '  ✗ Search users missing isFollowedByMe — follow state won\'t persist in Discover',
            );
            failed++;
            failures.push('Search users isFollowedByMe');
          }
        } else {
          console.log('  ⚠ No users returned from search');
        }
      }
    }
  }
  {
    // Search restaurants
    const { status, json } = await api('GET', '/search?type=restaurants');
    if (checkStatus(status, 200, 'GET /search?type=restaurants')) {
      const data = json?.data;
      if (data && typeof data === 'object' && 'restaurants' in data) {
        const restaurants = data.restaurants;
        if (Array.isArray(restaurants) && restaurants.length > 0) {
          const rErrors = validateObject(
            restaurants[0],
            RestaurantSchema,
            'search.restaurants[0]',
          );
          if (rErrors.length === 0) {
            console.log('  ✓ Search restaurants → Restaurant shape');
            passed++;
          } else {
            console.log('  ✗ Search restaurants shape errors:');
            rErrors.forEach((e) => console.log(`    → ${e}`));
            failed++;
            failures.push('Search restaurants shape');
          }

          // Critical: avgRating must be number not string
          const avgRating = restaurants[0].avgRating;
          if (typeof avgRating === 'number') {
            console.log(`  ✓ Restaurant.avgRating is number (${avgRating})`);
            passed++;
          } else {
            console.log(
              `  ✗ Restaurant.avgRating is ${typeof avgRating} ("${avgRating}") — iOS will crash`,
            );
            failed++;
            failures.push('Restaurant.avgRating type');
          }
        }
      }
    }
  }

  // ── Follows ───────────────────────────────────────────────────────────
  console.log('\n── Follows ──');
  if (currentUserId) {
    {
      const { status, json } = await api(
        'GET',
        `/users/${currentUserId}/followers?page=1&perPage=5`,
      );
      if (checkStatus(status, 200, 'GET /users/:id/followers')) {
        validateWrapped(
          json,
          UserSchema,
          'GET /users/:id/followers → [User] shape',
          { isArray: true, allowEmpty: true },
        );
      }
    }
    {
      const { status, json } = await api(
        'GET',
        `/users/${currentUserId}/following?page=1&perPage=5`,
      );
      if (checkStatus(status, 200, 'GET /users/:id/following')) {
        validateWrapped(
          json,
          UserSchema,
          'GET /users/:id/following → [User] shape',
          { isArray: true, allowEmpty: true },
        );
      }
    }
  }

  // ── Restaurants ───────────────────────────────────────────────────────
  console.log('\n── Restaurants ──');
  let restaurantId = '';
  if (feedRestaurantSlug) {
    const { status, json } = await api(
      'GET',
      `/restaurants/${feedRestaurantSlug}`,
    );
    if (checkStatus(status, 200, 'GET /restaurants/:slug')) {
      validateWrapped(
        json,
        RestaurantSchema,
        'GET /restaurants/:slug → Restaurant shape',
      );
      restaurantId = json?.data?.id || '';
    }
  } else {
    console.log('  ⚠ No restaurant slug from feed, trying nearby');
  }

  {
    // Nearby restaurants — Riyadh coords
    const { status, json } = await api(
      'GET',
      '/restaurants/nearby?lat=24.71&lng=46.67&radiusKm=50&limit=5',
    );
    if (checkStatus(status, 200, 'GET /restaurants/nearby')) {
      validateWrapped(
        json,
        RestaurantSchema,
        'GET /restaurants/nearby → [Restaurant] shape',
        { isArray: true, allowEmpty: true },
      );
      if (!restaurantId) {
        restaurantId = json?.data?.[0]?.id || '';
      }
    }
  }

  // Restaurant check-ins
  if (restaurantId) {
    const { status, json } = await api(
      'GET',
      `/restaurants/${restaurantId}/checkins?page=1&perPage=5`,
    );
    if (checkStatus(status, 200, 'GET /restaurants/:id/checkins')) {
      validateWrapped(
        json,
        CheckInSchema,
        'GET /restaurants/:id/checkins → [CheckIn] shape',
        { isArray: true, allowEmpty: true },
      );
    }
  }

  // ── Notifications ─────────────────────────────────────────────────────
  console.log('\n── Notifications ──');
  {
    const { status, json } = await api('GET', '/notifications?limit=5');
    if (checkStatus(status, 200, 'GET /notifications')) {
      validateWrapped(
        json,
        NotificationSchema,
        'GET /notifications → [Notification] shape',
        { isArray: true, allowEmpty: true },
      );
    }
  }
  {
    const { status, json } = await api('GET', '/notifications/unread-count');
    if (checkStatus(status, 200, 'GET /notifications/unread-count')) {
      const count = json?.data?.count;
      if (typeof count === 'number') {
        console.log(`  ✓ Unread count is number (${count})`);
        passed++;
      } else {
        console.log(`  ✗ Unread count is ${typeof count}`);
        failed++;
        failures.push('Unread count type');
      }
    }
  }

  // ── User Posts ────────────────────────────────────────────────────────
  // iOS uses FeedResponse for user posts too
  console.log('\n── User Posts ──');
  if (currentUserId) {
    const { status, json } = await api(
      'GET',
      `/users/${currentUserId}/posts?limit=5`,
    );
    if (checkStatus(status, 200, 'GET /users/:id/posts')) {
      validateWrapped(json, FeedResponseSchema, 'GET /users/:id/posts → FeedResponse shape');
    }
  }

  // ── Summary ───────────────────────────────────────────────────────────
  console.log('\n══════════════════════════════════════════');
  console.log(`  ✓ ${passed} passed`);
  console.log(`  ✗ ${failed} failed`);
  if (failures.length > 0) {
    console.log('\n  Failures:');
    for (const f of failures) {
      console.log(`    • ${f}`);
    }
  }
  console.log('══════════════════════════════════════════\n');

  process.exit(failed > 0 ? 1 : 0);
}

run().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
