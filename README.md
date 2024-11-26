# MailTicketSyncPro

MailTicketSyncPro is a powerful Redmine plugin designed to seamlessly integrate with email providers like Gmail and Outlook. It fetches inbox emails, creates tickets automatically in Redmine, and supports job scheduling and secure token management.

## Features

- Integrates with Gmail and Outlook inboxes.
- Automatically creates Redmine issues from unread emails.
- Securely stores and manages provider credentials and access tokens using encryption.
- Configurable job scheduling to fetch emails at desired intervals.
- Supports nested forms for managing related entities (e.g., mail providers and job schedules).
- Admin menu with intuitive UI and sidebar integration.

Supported OAuth providers:
* Azure AD (https://azure.microsoft.com)
* Google (https://google.com) (Under development)

## Installation

### Clone as Submodule

To include this plugin as a submodule in your Redmine project:

1. Navigate to your Redmine `plugins` directory:

```bash
cd /path/to/redmine/plugins
```

2. Add the plugin as a submodule:

```bash
git submodule add https://github.com/railsfactory-sivamanikandan/redmine_mail_ticket_sync_pro.git redmine_mail_ticket_sync_pro
```

3. Initialize and update the submodule:

```bash
git submodule init
git submodule update
```

4. Install plugin dependencies:

```bash
bundle install
```

1. Clone the repository into your Redmine plugins folder:

```bash
git clone https://github.com/railsfactory-sivamanikandan/redmine_mail_ticket_sync_pro.git
```

2. Install dependencies:

```bash
bundle install
```

3. Run migrations:

```bash
rake redmine:plugins:migrate NAME=mail_ticket_sync_pro RAILS_ENV=production
```

4. Set Up Active Record Encryption
If you are using encrypted columns for sensitive data, add the following configuration to your `config/application.yml`:

```yaml
active_record_encryption:
  primary_key: <%= ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"] %>
  secondary_key: <%= ENV["ACTIVE_RECORD_ENCRYPTION_SECONDARY_KEY"] %>
  key_derivation_salt: <%= ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"] %>
```
Ensure the corresponding environment variables are set in your server or .env file.

5. Restart Redmine.

## Configuration

1. Navigate to the Admin menu and select Mail Providers to configure Gmail or Outlook credentials.
2. Set up job schedules to specify how frequently emails are fetched.
3. Use the nested form to link tokens and schedules.

## Usage

1. Configure email providers in the Mail Providers section.
2. Define schedules to fetch emails and create tickets.
3. Access the generated tickets directly from your Redmine issues list.


## Database Structure

### Tables

1. `mail_ticket_providers`: Stores provider details (e.g., Gmail, Outlook) and credentials.
2. `mail_job_schedules`: Manages job schedules for fetching emails.
3. `mail_ticket_tokens`: Stores access tokens, refresh tokens, and associations to providers and schedules.

## Development

1. Run tests:

```bash
rake test RAILS_ENV=test

```

2. Generate jobs dynamically:

- A scheduler file (config/schedule.rb) is auto-generated based on job schedules.
- Uses the whenever gem to manage crontab entries.


##  Contributing
We welcome contributions! Please follow these steps:

1. Fork the repository.
2. Create a feature branch

```bash
git checkout -b feature/your-feature-name
```

3. Commit your changes:
```bash
git commit -m "Add your message here"
```
4. Push to your forked repository and create a pull request.


## License
This plugin is licensed under the MIT License. See the LICENSE file for details.
