import { DataSource } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { config } from 'dotenv';

config();

const dataSource = new DataSource({
  type: 'postgres',
  url: process.env.DATABASE_URL,
  ssl: process.env.DATABASE_URL?.includes('fly.dev')
    ? { rejectUnauthorized: false }
    : false,
  synchronize: false,
});

async function seed() {
  await dataSource.initialize();
  console.log('Connected to database');

  const qr = dataSource.createQueryRunner();

  // Add location_address column if missing
  try {
    await qr.query(
      `ALTER TABLE posts ADD COLUMN IF NOT EXISTS location_address VARCHAR(500)`,
    );
    console.log('Ensured location_address column exists');
  } catch (e) {
    console.log('location_address column may already exist');
  }

  const passwordHash = await bcrypt.hash('demo1234', 10);

  // Demo users
  const users = [
    {
      username: 'foodie_sara',
      email: 'sara@demo.invlog.app',
      displayName: 'Sara',
      bio: 'Riyadh food explorer',
      isVerified: true,
    },
    {
      username: 'chef_ahmed',
      email: 'ahmed@demo.invlog.app',
      displayName: 'Ahmed',
      bio: 'Chef & restaurant reviewer',
      isVerified: false,
    },
    {
      username: 'riyad_eats',
      email: 'riyad@demo.invlog.app',
      displayName: 'Riyad Eats',
      bio: 'Discovering the best food in Riyadh',
      isVerified: true,
    },
    {
      username: 'nora_bites',
      email: 'nora@demo.invlog.app',
      displayName: 'Nora',
      bio: 'Coffee & dessert lover',
      isVerified: false,
    },
    {
      username: 'faisal_gourmet',
      email: 'faisal@demo.invlog.app',
      displayName: 'Faisal',
      bio: 'Fine dining enthusiast',
      isVerified: false,
    },
  ];

  const userIds: string[] = [];

  for (const u of users) {
    const existing = await qr.query(
      `SELECT id FROM users WHERE username = $1`,
      [u.username],
    );
    if (existing.length > 0) {
      userIds.push(existing[0].id);
      console.log(`User ${u.username} already exists`);
      continue;
    }

    const result = await qr.query(
      `INSERT INTO users (username, email, display_name, bio, password_hash, is_verified, is_private, follower_count, following_count, post_count)
       VALUES ($1, $2, $3, $4, $5, $6, false, 0, 0, 0)
       RETURNING id`,
      [u.username, u.email, u.displayName, u.bio, passwordHash, u.isVerified],
    );
    userIds.push(result[0].id);
    console.log(`Created user: ${u.username}`);
  }

  // Real Riyadh restaurant locations (from Apple Maps / known locations)
  const riyadhPlaces = [
    {
      name: 'The Globe Restaurant',
      lat: 24.7113,
      lng: 46.6742,
      address: 'Al Faisaliyah Tower, King Fahd Rd, Riyadh',
      cuisines: ['Fine Dining', 'International'],
    },
    {
      name: 'Najd Village',
      lat: 24.6501,
      lng: 46.7101,
      address: 'King Abdullah Rd, Al Malaz, Riyadh',
      cuisines: ['Saudi', 'Traditional'],
    },
    {
      name: 'Lusin Armenian Restaurant',
      lat: 24.6925,
      lng: 46.6853,
      address: 'Tahlia St, Al Olaya, Riyadh',
      cuisines: ['Armenian', 'Mediterranean'],
    },
    {
      name: 'Piatto Restaurant',
      lat: 24.7025,
      lng: 46.6783,
      address: 'Al Urubah Rd, Al Olaya, Riyadh',
      cuisines: ['Italian', 'Pizza'],
    },
    {
      name: 'SALT Burger',
      lat: 24.7384,
      lng: 46.6534,
      address: 'The Zone, King Fahd Rd, Riyadh',
      cuisines: ['Burgers', 'Fast Food'],
    },
    {
      name: 'Myazu Japanese Restaurant',
      lat: 24.6991,
      lng: 46.6897,
      address: 'Tahlia St, Al Olaya, Riyadh',
      cuisines: ['Japanese', 'Sushi'],
    },
    {
      name: 'Mama Noura',
      lat: 24.6877,
      lng: 46.7005,
      address: 'Olaya St, Al Olaya, Riyadh',
      cuisines: ['Lebanese', 'Shawarma'],
    },
    {
      name: 'Barn\'s Coffee',
      lat: 24.7211,
      lng: 46.6523,
      address: 'King Fahd Rd, Riyadh',
      cuisines: ['Coffee', 'Cafe'],
    },
    {
      name: 'Al Baik',
      lat: 24.6312,
      lng: 46.7221,
      address: 'Khurais Rd, Riyadh',
      cuisines: ['Fast Food', 'Chicken'],
    },
    {
      name: 'Via Riyadh',
      lat: 24.7647,
      lng: 46.6389,
      address: 'King Abdullah Financial District, Riyadh',
      cuisines: ['International', 'Modern'],
    },
    {
      name: 'Takya Cafe',
      lat: 24.6935,
      lng: 46.6871,
      address: 'Tahlia St, Al Olaya, Riyadh',
      cuisines: ['Cafe', 'Brunch'],
    },
    {
      name: 'Nusr-Et Steakhouse',
      lat: 24.7653,
      lng: 46.6401,
      address: 'KAFD, Riyadh',
      cuisines: ['Steakhouse', 'Turkish'],
    },
  ];

  // Posts with check-in style content
  const postTemplates = [
    { content: 'Amazing kabsa! The spices here are incredible', rating: 5 },
    { content: 'Best coffee in Riyadh, hands down', rating: 4 },
    { content: 'The shawarma here never disappoints', rating: 5 },
    { content: 'Perfect spot for a weekend brunch with friends', rating: 4 },
    { content: 'The view from here is as good as the food', rating: 5 },
    { content: 'Great new find! Must try the lamb chops', rating: 4 },
    { content: 'Classic Riyadh dining. Always consistent', rating: 4 },
    { content: 'Their dessert menu is next level', rating: 5 },
    { content: 'Cozy atmosphere and excellent service', rating: 4 },
    { content: 'The sushi platter was fresh and perfectly prepared', rating: 5 },
    { content: 'Quick bite before heading out. Love this place', rating: 3 },
    { content: 'Tried the new menu items today. Highly recommend!', rating: 5 },
    { content: 'Weekend vibes. Great food, great company', rating: 4 },
    { content: 'The best burger joint in the city, no debate', rating: 5 },
    { content: 'Beautiful presentation and authentic flavors', rating: 4 },
  ];

  // Create posts — each user gets 3 posts at different restaurants
  let postIndex = 0;
  for (let u = 0; u < userIds.length; u++) {
    const userId = userIds[u];
    for (let p = 0; p < 3; p++) {
      const place = riyadhPlaces[(u * 3 + p) % riyadhPlaces.length];
      const template = postTemplates[postIndex % postTemplates.length];

      // Create post with location (check-in style)
      await qr.query(
        `INSERT INTO posts (author_id, content, rating, latitude, longitude, location_name, location_address, is_public, like_count, comment_count)
         VALUES ($1, $2, $3, $4, $5, $6, $7, true, $8, 0)`,
        [
          userId,
          template.content,
          template.rating,
          place.lat,
          place.lng,
          place.name,
          place.address,
          Math.floor(Math.random() * 20),
        ],
      );
      postIndex++;
    }

    // Update user's post count
    await qr.query(
      `UPDATE users SET post_count = 3 WHERE id = $1`,
      [userId],
    );
  }

  console.log(`Created ${postIndex} posts across ${userIds.length} users`);

  // Create some follows between demo users
  for (let i = 0; i < userIds.length; i++) {
    for (let j = 0; j < userIds.length; j++) {
      if (i !== j && Math.random() > 0.4) {
        try {
          await qr.query(
            `INSERT INTO follows (follower_id, target_type, target_id)
             VALUES ($1, 'user', $2)
             ON CONFLICT DO NOTHING`,
            [userIds[i], userIds[j]],
          );
        } catch (e) {
          // skip if exists
        }
      }
    }
  }

  // Update follower/following counts
  for (const uid of userIds) {
    const followerCount = await qr.query(
      `SELECT COUNT(*) as count FROM follows WHERE target_type = 'user' AND target_id = $1`,
      [uid],
    );
    const followingCount = await qr.query(
      `SELECT COUNT(*) as count FROM follows WHERE follower_id = $1 AND target_type = 'user'`,
      [uid],
    );
    await qr.query(
      `UPDATE users SET follower_count = $1, following_count = $2 WHERE id = $3`,
      [parseInt(followerCount[0].count), parseInt(followingCount[0].count), uid],
    );
  }

  console.log('Created follow relationships');
  console.log('Seed complete!');

  await dataSource.destroy();
}

seed().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
