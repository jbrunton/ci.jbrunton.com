# Provisioning scripts for ci.jbrunton.com

### Usage

Provision a new VM with `cap staging provision`. This will configure:

* Jenkins running on port 8080, with two jobs (one building every commit,
  another building every pull request).
* Sonar running on port 9000.

Some manual configuration is currently still necessary:

1. First, configure Jenkins security.
2. Add the Github personal access token for ci.jbrunton.com to Jenkins
   credentials.
3. Go to 'Configure System', and for both Github and Github Pull Request Builder
  sections set the Github API URL to 'https://api.github.com' and configure to
  use the personal access token.
