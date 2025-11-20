# GitHub Rate Limiting Solutions

The GitHub API has strict rate limits that can make data collection challenging. Here are several strategies to handle this:

## Option 1: Use GitHub Personal Access Token (Recommended)

**Benefits:** 5000 requests/hour vs 60 requests/hour (83x improvement!)

1. **Create a GitHub Personal Access Token:**
   - Go to https://github.com/settings/tokens
   - Click "Generate new token" → "Generate new token (classic)"
   - Give it a descriptive name like "RPU Data Collection"
   - Select scopes: `public_repo` (for public repositories)
   - Click "Generate token"
   - **Important:** Copy the token immediately (you won't see it again)

2. **Use the token:**
   ```bash
   export GITHUB_TOKEN=your_token_here
   crystal run src/collect_data.cr -- --github-user=ralsina --max-depth=3 --max-projects=500 --rate-limit=0.5
   ```

## Option 2: Optimized Settings for Unauthenticated Use

If you don't want to use a token, the updated script now handles rate limits much better:

```bash
crystal run src/collect_data.cr -- --github-user=ralsina --max-depth=2 --max-projects=200 --rate-limit=2.0
```

## What the Improvements Do

### Intelligent Rate Limiting
- **Monitors API credits** in real-time using GitHub's rate limit headers
- **Dynamic delays** - slower when running low on credits, faster when plenty available
- **Smart waiting** - calculates exact wait time until credits reset instead of guessing
- **Increased retries** - more retries when rate limits are exhausted

### Before vs After

**Before:**
- Fixed 1-second delay regardless of API status
- Max 3 retries then gives up
- Wastes time waiting even when credits are available

**After:**
- Adaptive: 0.5s delay with plenty of credits, 3x delay when running low
- Monitors remaining credits: slows down when < 100 left
- Waits intelligently when exhausted (calculates exact reset time)
- 5 retries with exponential backoff

## Recommended Commands

### With Token (Best Experience)
```bash
export GITHUB_TOKEN=your_token_here
crystal run src/collect_data.cr -- --github-user=ralsina --max-depth=3 --max-projects=500 --rate-limit=0.2
```

### Without Token (Optimized)
```bash
crystal run src/collect_data.cr -- --github-user=ralsina --max-depth=2 --max-projects=200 --rate-limit=1.0
```

### Quick Test
```bash
crystal run src/collect_data.cr -- --max-projects=10 --rate-limit=0.5
```

## Environment Variables

All of these work and can be combined:
```bash
export GITHUB_USER=ralsina
export GITHUB_TOKEN=your_token_here
export MAX_DEPTH=3
export MAX_PROJECTS=500
export RATE_LIMIT_DELAY=0.5
export DATA_FILE=public/projects.json

crystal run src/collect_data.cr
```

## Monitoring Progress

The script now shows helpful status messages:
- `→ Low API credits (5 left), waiting 3000s...` - Waiting for reset
- `→ Rate limit hit, waiting 1800s... (retry 1/5)` - Retrying after exhaustion
- `✓ Processed repo-name (15 deps)` - Successfully processed

This should make the data collection much more reliable and less frustrating!