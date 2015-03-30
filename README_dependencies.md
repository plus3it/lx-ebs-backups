This collection of scripts are designed to be run from the host requiring backup and restore services. The following is required for these scripts to work:

- AWS CLI tools
  - Installation instructions may be found [here](http://docs.aws.amazon.com/cli/latest/userguide/installing.html)
  - The installation archive (ZIP formatted) location is detailed at the immediately-prior link. As of the writing of this file, the direct-link to the installation archive may be found [here](https://s3.amazonaws.com/aws-cli/awscli-bundle.zip)
  - Once installed, the AWS CLI tools must be configured. Initial configuration instructions may be found [here](http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html)
It is assumed that the AWS CLI tools will either be placed in the system-wide shell-initialization script's PATH or within the executing user's PATH. These scripts do not assume a specific installation for the AWS CLI tools and will fail if the tools are not found in the invoking-account's PATH.
- IAM Permissions
  - Please see the README_AWSpermissions.md file for an enumeration of the minimum permissions-set required to allow the utilities to work
