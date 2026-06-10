#ifndef CCRYPTO_H
#define CCRYPTO_H

#include <stdint.h>
#include <stddef.h>

/// PBKDF2‑HMAC‑SHA1 key derivation (matches Chrome's cookie encryption).
/// Returns 0 on success, non‑zero on failure.
int ccrypto_pbkdf2_sha1(const char *password, int passwordLen,
                        const uint8_t *salt, int saltLen,
                        int iterations,
                        uint8_t *derivedKey, int keyLen);

/// AES‑128‑CBC decrypt with PKCS7 padding.
/// Returns 0 on success.  `plaintextLen` is set to the actual decrypted length.
int ccrypto_aes128cbc_decrypt(const uint8_t *key, int keyLen,
                              const uint8_t *iv,
                              const uint8_t *ciphertext, int ciphertextLen,
                              uint8_t *plaintext, int *plaintextLen);

#endif
