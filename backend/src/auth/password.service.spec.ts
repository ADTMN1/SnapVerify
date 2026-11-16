import { PasswordService } from './password.service';
import * as bcrypt from 'bcrypt';

describe('PasswordService', () => {
  let service: PasswordService;

  beforeEach(() => {
    service = new PasswordService();
  });

  it('hashes with Argon2id', async () => {
    const hash = await service.hash('correct horse battery staple');
    expect(hash).toMatch(/^\$argon2id\$/);
  });

  it('verifies correct and rejects wrong passwords', async () => {
    const hash = await service.hash('password123');
    expect((await service.verify(hash, 'password123')).valid).toBe(true);
    expect((await service.verify(hash, 'wrong')).valid).toBe(false);
    expect((await service.verify(hash, 'password123')).needsRehash).toBe(false);
  });

  it('verifies legacy bcrypt hashes and flags them for rehash', async () => {
    const legacy = await bcrypt.hash('oldpassword', 12);
    const result = await service.verify(legacy, 'oldpassword');
    expect(result.valid).toBe(true);
    expect(result.needsRehash).toBe(true);
  });

  it('rejects legacy bcrypt with wrong password', async () => {
    const legacy = await bcrypt.hash('oldpassword', 12);
    const result = await service.verify(legacy, 'nope');
    expect(result.valid).toBe(false);
  });

  it('returns invalid for unknown hash formats', async () => {
    const result = await service.verify('not-a-hash', 'anything');
    expect(result.valid).toBe(false);
    expect(result.needsRehash).toBe(false);
  });
});
