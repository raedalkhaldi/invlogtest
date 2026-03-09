import { SetMetadata } from '@nestjs/common';
import { ROLES_KEY } from '../constants/index.js';

export type UserRole = 'user' | 'restaurant';

export const Roles = (...roles: UserRole[]) => SetMetadata(ROLES_KEY, roles);
