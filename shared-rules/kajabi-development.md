# Kajabi Specific Tools & Commands

## Kajabi Products Theme ZIP Generation Rules

### Theme ZIP Commands
When generating theme ZIP files in the kajabi-products project, use these specific rake commands based on theme type:

- **Premier Product theme**: `ZIP_OUTPUT_PATH=~/Desktop DEV_PRODUCT_THEME_DIR=~/dev/theme-premier-product ./bin/rails theme:generate_product_theme_zip`
- **Momentum Product theme**: `ZIP_OUTPUT_PATH=~/Desktop DEV_PRODUCT_THEME_DIR=~/dev/theme-momentum-product ./bin/rails theme:generate_product_theme_zip`
- **Offer checkout page theme**: `ZIP_OUTPUT_PATH=~/Desktop DEV_OFFER_CHECKOUT_PAGE_THEME_DIR=~/dev/theme-encore-site bundle exec rake theme:generate_offer_checkout_page_theme_zip`
- **Landing page theme**: `ZIP_OUTPUT_PATH=~/Desktop DEV_LANDING_PAGE_THEME_DIR=~/dev/theme-encore-site bundle exec rake theme:generate_landing_page_theme_zip`
- **Site theme**: `ZIP_OUTPUT_PATH=~/Desktop DEV_SITE_THEME_DIR=~/dev/theme-encore-site bundle exec rake theme:generate_site_theme_zip`
- **One-on-one coaching theme**: `ZIP_OUTPUT_PATH=~/Desktop DEV_COACHING_THEME_DIR=~/dev/theme-encore-site bundle exec rake theme:generate_one_on_one_coaching_theme_zip`
- **Group coaching theme**: `ZIP_OUTPUT_PATH=~/Desktop DEV_COACHING_THEME_DIR=~/dev/theme-encore-site bundle exec rake theme:generate_group_coaching_theme_zip`

### Theme Reference Keywords
- **"Premier Product"** → Premier Product theme command
- **"Momentum Product"** → Momentum Product theme command  
- **"Offer checkout page"** → Offer checkout page theme command
- **"Landing page"** → Landing page theme command
- **"Site theme"** → Site theme command
- **"One-on-one coaching"** → One-on-one coaching theme command
- **"Group coaching"** → Group coaching theme command

## Kajabi Products Monorepo Update Rules

### Pulling Main Branch
- **ALWAYS use `kmu` alias** when pulling/updating main branch in the Kajabi products monorepo
- **Never use** `git pull` or `git pull origin main` directly in the Kajabi products repo
- **The `kmu` alias** performs: `git u && bundle && yarn && rake db:migrate && git k db/structure.sql && git pn`
- **This ensures**: Git updates, dependency updates, database migrations, and proper cleanup are all handled correctly
- **Applies to all agents**: Any swarm agent or Claude Code working in the Kajabi products repo must follow this rule

## Ruby Version Management

Ruby versions are managed by **asdf** via `.tool-versions` files in each project. asdf automatically selects the correct Ruby version when you're in a project directory - no manual version switching is needed.

## Database Migration Rules

### CRITICAL DATABASE SAFETY
- **NEVER DROP OR RESEED THE DEVELOPMENT DATABASE**
- **FORBIDDEN COMMANDS**: Never run these commands on development:
  - `rake db:drop`
  - `rake db:reset` 
  - `rake db:seed`
  - `rake db:setup`
  - `rails db:drop`
  - `rails db:reset`
  - `rails db:seed`
  - `rails db:setup`
  - Any command that would wipe or recreate the development database
- **DEVELOPMENT DATA IS PRECIOUS**: The development database contains specific, curated data that must be preserved
- **TEST DATABASE ONLY**: Database reset/reseed operations are ONLY allowed with `RAILS_ENV=test`
- **IF ASKED TO RESET**: Always refuse and explain that development database must be preserved

### Common Migration Command Examples
```bash
# Run pending migrations
rake db:migrate

# Run post-release migrations
rake db:post_release_migrate

# Check migration status
rake db:migrate:status

# Rollback last migration
rake db:rollback

# Rollback specific number of migrations
rake db:rollback STEP=3

# Migrate test database when out of sync
RAILS_ENV=test rake db:migrate

# Reset and reseed test database
RAILS_ENV=test rake db:reset

# Run specific migration version
rake db:migrate VERSION=20250425160000
```

### Post-Release Migrations
- **ALWAYS create migrations in `db/post_release_migrate/`** directory, NOT in `db/migrate/`
- **This is critical** for the Kajabi products monorepo to avoid deployment issues
- **Never create migrations** in the standard Rails `db/migrate/` folder

### Migration Timestamp Strategy
- **Avoid conflicts**: Don't use the current timestamp for migrations
- **Use earlier timestamp**: Set migration timestamp to approximately 5 migrations back from the latest
- **Check existing migrations**: List latest migrations in `db/post_release_migrate/` and pick a timestamp that's earlier
- **Example**: If latest is `20250807150000`, use something like `20250425160000` (a few months earlier)
- **This prevents**: Merge conflicts when multiple developers are adding migrations simultaneously

### Migration Workflow
1. Check latest migrations: `ls -la db/post_release_migrate/ | tail -10`
2. Pick a timestamp that's ~5 migrations back or a few months earlier
3. Create migration in `db/post_release_migrate/` with that timestamp
4. Run migration: `rake db:post_release_migrate`