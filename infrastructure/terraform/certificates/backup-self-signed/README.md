# Self-Signed Certificate Backup

**Date:** November 25, 2025  
**Status:** Archived - No longer in use

## Background

These self-signed certificate files were used during initial HTTPS setup before migrating to a custom domain with ACM-issued certificate.

## Files

- `certificate.pem` - Self-signed SSL certificate
- `private-key.pem` - Private key for self-signed certificate

## Migration

The application has been migrated to use:
- **Custom Domain:** api.blacksteep.com
- **Certificate Provider:** AWS Certificate Manager (ACM)
- **Certificate Issuer:** Amazon RSA 2048 M04
- **Validation Method:** DNS validation via Route 53

## Status

These files are kept as backup only and are **NOT** used by the current infrastructure. The ACM certificate is managed entirely through Terraform and AWS services.

## Safe to Delete

These files can be safely deleted if desired. They are not referenced anywhere in the codebase or infrastructure configuration.

## Related Documentation

- See `CUSTOM_DOMAIN_VERIFICATION_REPORT.md` for migration verification
- See `.kiro/specs/custom-domain-migration/` for complete migration spec
