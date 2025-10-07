# AWS S3 Website Redirect Buildkite Plugin

A Buildkite plugin to add website redirects via Amazon S3 by setting the `x-amz-website-redirect-location` metadata on S3 objects.

This plugin uses the AWS CLI to create empty S3 objects with redirect metadata, which allows S3 static websites to redirect old URLs to new locations.

## How It Works

The plugin executes the following AWS CLI command for each redirect:

```bash
aws s3 cp --website-redirect "https://example.com/my-new-docs/" - "s3://example.com/my-old-docs/" <<< ""
```

This creates an empty object in S3 with the `x-amz-website-redirect-location` metadata set to the destination URL. When a user accesses the old URL on an S3 static website, S3 will return an HTTP 301 redirect to the new location.

### Important: Path Redirect Limitation

**The redirect destination is static and does NOT automatically preserve or append the original path.**

For example, if you create a redirect from `my-old-docs/` to `https://example.com/my-new-docs/`:

- ✅ Accessing `https://example.com/my-old-docs/` redirects to `https://example.com/my-new-docs/`
- ❌ Accessing `https://example.com/my-old-docs/page.html` **also** redirects to `https://example.com/my-new-docs/` (NOT to `https://example.com/my-new-docs/page.html`)

**Best practice**: Redirect specific HTML files to specific HTML files, not directory paths.

**Workarounds for Path Preservation:**

1. **Create individual redirects for each file/page** (what this plugin does - list each redirect explicitly)
2. **Use S3 website routing rules** in your bucket configuration with `ReplaceKeyPrefixWith` for automatic path substitution
3. **Use CloudFront Functions or Lambda@Edge** for dynamic redirect logic

This plugin is best suited for:
- Redirecting specific HTML files or pages to their new locations
- Consolidating multiple old pages to a single landing page
- Setting up redirects for moved or renamed documentation pages

## Quick Start

### Single Redirect

```yaml
steps:
  - label: ":books: Publish Docs"
    command: "yarn docs build"
    plugins:
      - envato/aws-s3-sync#v0.5.0:
          source: docs/.vitepress/dist/
          destination: s3://example.com/my-project/
      - envato/aws-s3-website-redirect#v0.1.0:
          bucket: example.com
          source: my-project/old-api-docs.html
          destination: https://example.com/my-project/api-reference.html
```

### Multiple Redirects

```yaml
steps:
  - label: ":books: Publish Docs"
    command: "yarn docs build"
    plugins:
      - envato/aws-s3-sync#v0.5.0:
          source: docs/.vitepress/dist/
          destination: s3://example.com/my-project/
      - envato/aws-s3-website-redirect#v0.1.0:
          bucket: example.com
          redirects:
            - source: my-project/quickstart.html
              destination: https://example.com/my-project/getting-started.html
            - source: my-project/old-tutorial.html
              destination: https://example.com/my-project/tutorial.html
            - source: my-project/deprecated-api.html
              destination: https://example.com/my-project/api-reference.html
```

### With Custom Region

```yaml
steps:
  - label: ":books: Publish Docs"
    plugins:
      - envato/aws-s3-website-redirect#v0.1.0:
          bucket: my-docs-bucket
          region: ap-southeast-2
          redirects:
            - source: my-project/installation.html
              destination: https://example.com/my-project/setup.html
```

## Configuration

### Required

#### `bucket` (string)

The name of the S3 bucket where the redirects will be created.

**Example:** `example.com`

### Optional

#### `region` (string)

The AWS region where the S3 bucket is located.

**Default:** `us-east-1`

### Single Redirect Mode

#### `source` (string)

The S3 path to redirect from (relative to the bucket root).

**Example:** `my-old-docs/`

#### `destination` (string)

The full URL to redirect to.

**Example:** `https://example.com/my-new-docs/`

### Multiple Redirects Mode

#### `redirects` (array)

An array of redirect objects, each containing:

- `source` (string, required): The S3 path to redirect from
- `destination` (string, required): The full URL to redirect to

## Configuration Summary Table

| Option | Type | Required | Default | Description |
|--------|------|----------|---------|-------------|
| `bucket` | string | Yes | - | S3 bucket name |
| `source` | string | No* | - | Single redirect source path |
| `destination` | string | No* | - | Single redirect destination URL |
| `redirects` | array | No* | - | Array of redirect objects |
| `region` | string | No | `us-east-1` | AWS region |

*Either use `source`+`destination` for a single redirect, or `redirects` for multiple redirects.

## Integration Examples

### Example 1: Add Redirect to Existing Publish Docs Step

Modify your existing "Publish Docs" step in `.buildkite/pipeline.yml`:

```yaml
- label: ":books: Publish Docs"
  key: publish-docs
  command:
    - "yarn install"
    - "yarn docs build"
  if: build.branch == pipeline.default_branch
  plugins:
    - envato/aws-assume-role#v0.2.0:
        role: arn:aws:iam::123456789012:role/docs-role
    - docker#v5.3.0:
        image: node:18-alpine
        environment:
          - CI
    - envato/aws-s3-sync#v0.5.0:
        source: docs/.vitepress/dist/
        destination: s3://example.com/my-project/
        delete: true
    # Add redirects after syncing
    - envato/aws-s3-website-redirect#v0.1.0:
        bucket: example.com
        source: my-project/old-getting-started.html
        destination: https://example.com/my-project/getting-started.html
    - envato/aws-cloudfront-invalidation#v0.1.0:
        distribution-id: EXAMPLEID123
        paths:
          - /my-project/*
  timeout_in_minutes: 10
```

### Example 2: Multiple Redirects After Deployment

For projects with multiple renamed or moved pages:

```yaml
- label: ":books: Publish Docs with Redirects"
  command:
    - "yarn docs build"
  plugins:
    - envato/aws-assume-role#v0.2.0:
        role: arn:aws:iam::123456789012:role/docs-role
    - envato/aws-s3-sync#v0.5.0:
        source: docs/.vitepress/dist/
        destination: s3://example.com/my-project/
    - envato/aws-s3-website-redirect#v0.1.0:
        bucket: example.com
        region: us-east-1
        redirects:
          # Redirect old CLI reference to new location
          - source: my-project/cli-reference.html
            destination: https://example.com/my-project/reference/cli.html
          # Redirect deprecated API docs
          - source: my-project/api-v1.html
            destination: https://example.com/my-project/api-v2.html
          # Redirect moved tutorial
          - source: my-project/setup-tutorial.html
            destination: https://example.com/my-project/getting-started.html
```

### Example 3: Standalone Redirect Step

Create a separate step to add redirects without redeploying content:

```yaml
- label: ":redirect: Update Documentation Redirects"
  command: "echo 'Adding redirects for renamed pages'"
  if: build.branch == pipeline.default_branch
  plugins:
    - envato/aws-assume-role#v0.2.0:
        role: arn:aws:iam::123456789012:role/docs-role
    - envato/aws-s3-website-redirect#v0.1.0:
        bucket: example.com
        redirects:
          - source: my-project/deprecated-feature.html
            destination: https://example.com/my-project/index.html
          - source: my-project/old-guide.html
            destination: https://example.com/my-project/guide.html
```

### Example 4: Redirecting Individual Pages

```yaml
- envato/aws-s3-website-redirect#v0.1.0:
    bucket: example.com
    source: my-project/old-page.html
    destination: https://example.com/my-project/new-page.html
```

### Example 5: Redirecting to External Documentation

```yaml
- envato/aws-s3-website-redirect#v0.1.0:
    bucket: example.com
    source: my-project/external-integration.html
    destination: https://external-docs.example.com/integration-guide.html
```

## Common Use Cases

This plugin is particularly useful for documentation sites where you want to:

- **Redirect renamed or moved documentation pages** - Maintain links when restructuring docs
- **Maintain backward compatibility for bookmarked URLs** - Don't break existing links
- **Consolidate multiple old paths to a single new location** - Merge deprecated sections
- **Set up temporary redirects during content migration** - Gradual migration support
- **Redirect deprecated features to current equivalents** - Keep users on supported pages
- **Redirect entire sections** - Move documentation categories

## Plugin Order

The plugin runs during the `post-command` hook, so it executes **after** your build command completes successfully. This is the ideal order:

1. Build your documentation (`yarn docs build`)
2. Sync to S3 (`aws-s3-sync` plugin)
3. **Add redirects** (`s3-website-redirect` plugin) ← This plugin
4. Invalidate CloudFront cache (`aws-cloudfront-invalidation` plugin)

## Requirements

- AWS CLI must be installed and available in the PATH
- Appropriate AWS credentials must be configured (via IAM role or environment variables)
- The S3 bucket must be configured as a static website
- The IAM role/user must have `s3:PutObject` permissions on the bucket

### Required IAM Permissions

Ensure your IAM role has the `s3:PutObject` permission:

```json
{
  "Effect": "Allow",
  "Action": "s3:PutObject",
  "Resource": "arn:aws:s3:::example.com/*"
}
```

## Testing Locally

You can test the AWS command manually:

```bash
# Single redirect
aws s3 cp \
  --website-redirect "https://example.com/my-project/new-path/" \
  - \
  "s3://example.com/my-project/old-path/" \
  <<< ""

# Verify the redirect was created
aws s3api head-object \
  --bucket example.com \
  --key my-project/old-path/ \
  --query 'WebsiteRedirectLocation'

# Test the redirect in action
curl -I https://example.com/my-project/old-path/
```

Look for a `Location:` header in the curl response showing the redirect destination.

## Best Practices

1. **Be consistent with file extensions**:
   - ✅ `source: my-project/old-page.html`
   - ✅ `source: my-project/index.html`
   - ⚠️ For directory redirects, use trailing slashes: `source: my-project/old-section/`

2. **Use absolute URLs** for destinations:
   - ✅ `destination: https://example.com/my-project/new/`
   - ❌ `destination: /my-project/new/`

3. **Add redirects after syncing** to ensure all content is deployed first

4. **Document your redirects** in a separate file or comment in the pipeline

5. **Test redirects** before removing old content from your repository

6. **Redirect files, not directories** - due to the path limitation, redirect specific HTML files to specific destinations

7. **Use meaningful redirect destinations** - redirect to the most relevant replacement page

8. **Keep redirects indefinitely** - users may have old bookmarks years later

## Migration Example

When restructuring documentation, deploy new structure first, then add redirects:

```yaml
# Step 1: Deploy new structure
- label: ":books: Deploy Restructured Docs"
  command: "yarn docs build"
  plugins:
    - envato/aws-s3-sync#v0.5.0:
        source: docs/.vitepress/dist/
        destination: s3://example.com/my-project/

# Step 2: Add redirects for all old paths
- label: ":redirect: Add Migration Redirects"
  command: "echo 'Setting up redirects...'"
  plugins:
    - envato/aws-s3-website-redirect#v0.1.0:
        bucket: example.com
        redirects:
          - source: my-project/installation.html
            destination: https://example.com/my-project/guide/installation.html
          - source: my-project/quickstart.html
            destination: https://example.com/my-project/guide/quickstart.html
          - source: my-project/api-docs.html
            destination: https://example.com/my-project/reference/api.html
          - source: my-project/cli-commands.html
            destination: https://example.com/my-project/reference/cli.html

# Step 3: Invalidate cache
- label: ":cloudfront: Invalidate Cache"
  command: "echo 'Invalidating CloudFront...'"
  plugins:
    - envato/aws-cloudfront-invalidation#v0.1.0:
        distribution-id: EXAMPLEID123
        paths:
          - /my-project/*
```

## Troubleshooting

### Permission Denied Errors

Ensure your IAM role has the `s3:PutObject` permission (see Requirements section above).

### Redirects Not Working

1. **Verify your S3 bucket is configured for static website hosting** - Check bucket properties
2. **Check that the source path matches exactly** - Include/exclude trailing slashes consistently
3. **Test the redirect directly**: `curl -I https://example.com/my-project/old-path/`
4. **Look for a `Location:` header** in the response showing the redirect destination
5. **Verify the object exists in S3**: Use `aws s3api head-object` to check the metadata

### CloudFront Caching

If using CloudFront, you may need to invalidate the redirect path to see changes immediately:

```yaml
- envato/aws-cloudfront-invalidation#v0.1.0:
    distribution-id: EXAMPLEID123
    paths:
      - /my-project/old-path/
      - /my-project/new-path/
```

CloudFront will cache the redirect response, so without invalidation, users may see old behavior until the cache expires.

### Redirect Goes to Wrong Destination

Remember that the destination is static. If you're trying to redirect an entire directory tree while preserving paths, consider using S3 website routing rules instead:

```xml
<RoutingRules>
  <RoutingRule>
    <Condition>
      <KeyPrefixEquals>my-old-docs/</KeyPrefixEquals>
    </Condition>
    <Redirect>
      <ReplaceKeyPrefixWith>my-new-docs/</ReplaceKeyPrefixWith>
    </Redirect>
  </RoutingRule>
</RoutingRules>
```

This approach preserves the path structure automatically. The aws-s3-website-redirect Buildkite plugin may implement this feature in the future.

## Additional Resources

- [AWS S3 Website Redirects Documentation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/how-to-page-redirect.html)
- [AWS S3 Website Routing Rules](https://docs.aws.amazon.com/AmazonS3/latest/userguide/how-to-page-redirect.html#advanced-conditional-redirects)
- [Buildkite Plugin Documentation](https://buildkite.com/docs/plugins)

## License

MIT (see [LICENSE](LICENSE) file)
