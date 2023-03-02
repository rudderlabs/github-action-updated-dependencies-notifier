# Check outdate dependencies and create issue

This action has the capability to identify one or more outdated dependencies. Based on this detection, it will either create a new GitHub issue (if no issue with the specified `title` exists) or update an existing one. After the action is completed, it will pass the issue URL and a flag indicating whether or not an outdated dependency was detected as output.

## Inputs

### `outdated-dependency-names:`

**Required** Please input the names of the dependencies for which you want to detect outdated versions in the following format: `groupID:artifactID` without version.

### `directory`

**Required** Please input the directory where the `build.gradle` file located is located.

### `library`

**Optional** Please input the name of the `library` where the `build.gradle` file is located. This value is needed in the case of a BOM dependency. (This case is tested where the `build.gradle` file is present in a different library, not in the root or app `build.gradle` file.)

### `repository-urls`

**Optional** Please input the repository URL for all dependencies. The default repository URL is `https://repo.maven.apache.org/maven2/`.

### `alternative-dependency-lookup`

**Optional** [BETA] Please input the dependency if the normal process does not work. This is an alternate process to look for the updated dependency, which will override the default method for inputting dependencies. Additionally, make sure to pass the complete repository URL. Only a single dependency value needs to be passed.

### `alternative-dependency-lookup-url`

**Optional** [BETA] Please input the complete repository URL. Only a single URL needs to be passed.

### `title`

**Optional** Please provide the title for the issue. If a value is not specified, the `issue` will not be created or updated. The script will first check if an issue with the given `title` already exists. If it does, the issue will be edited. If it does not exist, a new issue with the specified title will be created.

### `body`

**Optional** Please provide a description for the issue. The default description is: "Update the `outdated-dependency-names` SDK from the current version `x.y.z` to the latest version `x.y.z`."

### `assignee`

**Optional** Please provide the `Github ID` of the person who will be assigned to the new issue.

### `labels`

**Optional** Please provide the label for the `issue`.

### `color`

**Optional** Please provide the `color` for the label. The default color is set to `FBCA04`.

## Outputs

### `issue-url`

The URL of the created or edited GitHub issue.

## `has-outdated-dependencies`

A flag that indicates whether any outdated dependencies were detected. The value will be `true` if an outdated dependency was found, and `false` if no outdated dependency were detected.

## Example usage

Obtain the most recent tag from the GitHub release section and utilize that version in place of v1.0.0.

### Inputs

```yaml
steps:
  - uses: actions/checkout@v3
  - name: Check outdated dependencies and create issue
    id: check-outdated-dependencies-and-create-issue
    uses: rudderlabs/github-action-updated-dependencies-notifier@main
    with:
      outdated-dependency-names: "com.amplitude:android-sdk"
      directory: "amplitude/build.gradle"
      library: "amplitude"
      repository-urls: "https://oss.sonatype.org/content/repositories/releases/, https://maven.google.com/, https://maven.singular.net/, https://maven.fullstory.com, https://s3-us-west-2.amazonaws.com/si-mobile-sdks/android/"
      alternative-dependency-lookup: "com.singular.sdk:singular_sdk"
      alternative-dependency-lookup-url: "https://maven.singular.net/com/singular/sdk/singular_sdk/maven-metadata.xml"
      title: "fix: update Amplitude SDK to the latest version"
      assignee: "1abhishekpandey"
      labels: "outdatedDependency"
      color: "FBCA04"
    env:
      GH_TOKEN: ${{ github.token }}
```

### Outputs

```yaml
steps:
  - uses: actions/checkout@v3
  - name: Check outdated dependencies and create issue
   id: check-outdated-dependencies-and-create-issue
    uses: rudderlabs/github-action-updated-dependencies-notifier@main
    with:
      outdated-dependency-names: "com.amplitude:android-sdk"
      directory: "amplitude/build.gradle"
      title: "fix: update Amplitude SDK to the latest version"
    env:
      GH_TOKEN: ${{ github.token }}

  - name: Get the github issue url
    if: steps.check-outdated-dependencies-and-create-issue.outputs.issue-url != ''
    run: echo "The Github issue url is ${{ steps.check-outdated-dependencies-and-create-issue.outputs.issue-url }}"

  - name: Outdated dependency is detected
    if: steps.check-outdated-dependencies-and-create-issue.outputs.has-outdated-dependencies == 'true'
    run: echo "Outdated dependency is detected"
```
