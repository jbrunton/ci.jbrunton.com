# Provisioning scripts for ci.jbrunton.com

### Usage

Provision a new VM with `cap staging provision`. This will configure:

* Jenkins running on port 8080, with two jobs (one building every commit,
  another building every pull request).
* Sonar running on port 9000.

Some manual configuration is still necessary:

* Add the personal access token to Jenkins credentials.
* Go to 'Configure System', and for both Github and Github Pull Request Builder
  sections set the Github API URL to 'https://api.github.com' and configure to
  use the personal access token.
