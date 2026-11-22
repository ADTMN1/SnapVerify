import { Injectable } from '@nestjs/common';
import * as argon2 from '@node-rs/argon2';
import * as bcrypt from 'bcrypt';

// Argon2id parameters (OWASP-recommended baseline for interactive logins)
const ARGON2_OPTIONS: argon2.Options = {
  // node-rs Algorithm.Argon2id === 2 (const enum; referenced numerically for
  // isolatedModules compatibility)
  algorithm: 2,
  memoryCost: 19456, // 19 MiB
  timeCost: 2,
  parallelism: 1,
};

const BCRYPT_SALT_ROUNDS = 12;

function isArgon2(hash: string): boolean {
  return hash.startsWith('$argon2');
}

@Injectable()
export class PasswordService {
  hash(password: string): Promise<string> {
    return argon2.hash(password, ARGON2_OPTIONS);
  }

  /**
   * Verify against an existing stored hash. Supports legacy bcrypt hashes
   * (pre-email-auth users) and Argon2id hashes.
   * Returns `needsRehash: true` when the stored hash is not Argon2id so the
   * caller can transparently upgrade the hash after a successful login.
   */
  async verify(
    storedHash: string,
    password: string,
  ): Promise<{ valid: boolean; needsRehash: boolean }> {
    if (isArgon2(storedHash)) {
      return {
        valid: await argon2.verify(storedHash, password),
        needsRehash: false,
      };
    }
    if (storedHash.startsWith('$2')) {
      const valid = await bcrypt.compare(password, storedHash);
      return { valid, needsRehash: valid };
    }
    return { valid: false, needsRehash: false };
  }
}
