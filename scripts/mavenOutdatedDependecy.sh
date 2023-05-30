#!/bin/bash

# Mandatory Input
MULTIPLE_DEPENDENCIES_INPUT=$1
RELATIVE_PATH=$2

if [ -z "$RELATIVE_PATH" ] || [ -z "$MULTIPLE_DEPENDENCIES_INPUT" ]; then
    echo "Mandatory fields must be present."
    exit 1
fi

# Optional Input
LIBRARY=$3
MULTIPLE_REPOSITORY_URLS=$4
ALTERNATIVE_SDK=$5
ALTERNATIVE_URL=$6
# Issue Inputs
TITLE=$7
ASSIGNEE=$8
BODY=$9
LABELS=${10}
COLOR=${11}

echo "Dependencies: $MULTIPLE_DEPENDENCIES_INPUT"
echo "Path of the build.gradle file: $RELATIVE_PATH"
echo "Library: $LIBRARY"
echo "Repository urls: $MULTIPLE_REPOSITORY_URLS"
echo "Alternative SDK: $ALTERNATIVE_SDK"
echo "Alternative url: $ALTERNATIVE_URL"
echo "Title: $TITLE"
echo "Assignee: $ASSIGNEE"
echo "Body: $BODY"
echo "Labels: $LABELS"
echo "Color: $COLOR\n\n"

function split_dependencies() {
    # Save the original IFS
    local original_ifs=$IFS
    # Set IFS to a comma
    IFS=","
    # Split the string into an array
    local dependencies=($1)
    # Reset the original IFS
    IFS=$original_ifs
    echo "${dependencies[@]}"
}

delimit_string() {
    local string=$1
    local delimiter=$2
    IFS=$delimiter read -ra str_array <<<"$string"
    echo "${str_array[@]}"
    IFS=$original_ifs
}

# Function to create a Maven dependency XML string
function create_dependency_xml() {
    groupID=${DELIMITED_DEPENDENCY[0]}
    artifactID=${DELIMITED_DEPENDENCY[1]}
    version=${DELIMITED_DEPENDENCY[2]}

    # Check if all three arguments are provided
    if [ -z "$groupID" ] || [ -z "$artifactID" ] || [ -z "$version" ]; then
        echo "false"
        return 0
    fi

    # Build the XML string with the provided arguments
    DEPENDENCY_XML="\n\t\t<dependency>\n
    \t\t\t<groupId>${groupID}</groupId>\n
    \t\t\t<artifactId>${artifactID}</artifactId>\n
    \t\t\t<version>${version}</version>\n
    \t\t</dependency>"

    # Return the XML string
    echo $DEPENDENCY_XML
}

# Function to create a Repository XML string
function create_repository_xml() {
    urls=${REPOSITORY_URLS[@]}

    REPOSITORY_XML="<repositories>\n"
    count=1
    for url in ${urls[@]}; do
        id="id$count"
        REPOSITORY_XML+="\t\t<repository>\n
        \t\t\t<id>${id}</id>\n
        \t\t\t<url>${url}</url>\n
        \t\t</repository>\n"
        ((count++))
    done
    REPOSITORY_XML+="\t</repositories>\n\n"

    # Return the XML string
    echo $REPOSITORY_XML
}

function get_individual_dependecy() {
    # Get the dependecy detail from the build.gradle file
    DEPENDENCY=$(grep "$individual_dependency" "$RELATIVE_PATH")

    # If dependency is enclosed in single quotes
    INDIVIDUAL_DEPENDENCY=$(echo "$DEPENDENCY" | sed -n "s/.*'\([^']*\)'.*/\1/p" | tr -d ' ')
    # If dependency is enclosed in double quotes
    if [ -z "$INDIVIDUAL_DEPENDENCY" ]; then
        INDIVIDUAL_DEPENDENCY=$(echo "$DEPENDENCY" | sed -n 's/.*"\([^"]*\)".*/\1/p' | tr -d ' ')
    fi

    echo "$INDIVIDUAL_DEPENDENCY"
}

REPOSITORY_URLS=($(split_dependencies "$MULTIPLE_REPOSITORY_URLS"))
REPOSITORY_XML=$(create_repository_xml "${REPOSITORY_IDS[@]}" "${REPOSITORY_URLS[@]}")
MULTIPLE_DEPENDENCIES=($(split_dependencies "$MULTIPLE_DEPENDENCIES_INPUT"))

# Fetch all the dependencies from gradle file
AGGREGATE_DEPENDENCIES=""
for individual_dependency in "${MULTIPLE_DEPENDENCIES[@]}"; do
    echo "Checking for: $individual_dependency"

    INDIVIDUAL_DEPENDENCY=($(get_individual_dependecy "$individual_dependency" "$RELATIVE_PATH"))
    echo "Individual dependency: $INDIVIDUAL_DEPENDENCY"
    delimiter=":"
    DELIMITED_DEPENDENCY=($(delimit_string "$INDIVIDUAL_DEPENDENCY" "$delimiter"))

    dependency_xml=$(create_dependency_xml "${DELIMITED_DEPENDENCY[@]}")
    if [ "$dependency_xml" != "false" ]; then
        AGGREGATE_DEPENDENCIES+="$dependency_xml"
    else
        if [ -n "$LIBRARY" ]; then
            echo "Finding version using 'gradlew <library>:dependencies' command"
            FIND_VERSION=$(./gradlew $LIBRARY:dependencies | grep -i ""$individual_dependency" -> " | cut -d ">" -f2 | sed 's/ //g' | sed -n '1p')
            if [ -n "$FIND_VERSION" ]; then
                echo "Found version: $FIND_VERSION"
                INDIVIDUAL_DEPENDENCY="$individual_dependency:$FIND_VERSION"
                delimiter=":"
                DELIMITED_DEPENDENCY=($(delimit_string "$INDIVIDUAL_DEPENDENCY" "$delimiter"))
                dependency_xml=$(create_dependency_xml "${DELIMITED_DEPENDENCY[@]}")
                AGGREGATE_DEPENDENCIES+="$dependency_xml"
            fi
        fi
    fi
done

create_pom_xml() {
    cat <<EOF >pom.xml
<?xml version="1.0" encoding="UTF-8"?>

<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/maven-v4_0_0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>temporaryGroupID</groupId>
    <artifactId>temporaryArtifactID</artifactId>
    <version>1.0.0</version>

    ${1}

    <dependencies>
        ${2}
    </dependencies>
</project>
EOF
}
# Create a pom.xml file
create_pom_xml "$REPOSITORY_XML" "$AGGREGATE_DEPENDENCIES"
cat pom.xml

# Scan the project's dependencies and produces a report of those dependencies which have newer versions available
# NOTE: It'll not scan for deprecated dependency
OUTPUT=$(mvn versions:display-dependency-updates)

echo "\n\n$OUTPUT\n\n"

NEWER_DEPENDENCIES=$(echo "$OUTPUT" | sed -n '/The following dependencies in Dependencies have newer versions:/,$p')

function alternative_approach() {
    input_string=$(curl "$1")
    matching_string="<versioning>"
    # Using parameter expansion to extract the content after the matching string
    versioning="${input_string#*$matching_string}"
    # Search string
    search_string="<versions>"
    # Remove content after search string
    output=$(echo $versioning | sed "s/$search_string.*$//")
    version=$(echo $output | grep -o '[0-9]*\.[0-9]*\.[0-9]*' | sed -n '1p')
    echo $version
}

# Initialize an empty body
body=()

HAS_OUTDATED_DEPENDENCIES="false"
# Construct body
for individual_dependency in "${MULTIPLE_DEPENDENCIES[@]}"; do
    echo "Checking for: $individual_dependency"
    OUTDATED_DEPENDENCY=""
    if echo "$NEWER_DEPENDENCIES" | grep -q "$individual_dependency"; then
        OUTDATED_DEPENDENCY=$(echo "$NEWER_DEPENDENCIES" | grep "$individual_dependency")
    fi

    # Fetch current version
    INDIVIDUAL_DEPENDENCY=($(get_individual_dependecy "$individual_dependency" "$RELATIVE_PATH"))
    delimiter=":"
    DELIMITED_DEPENDENCY=($(delimit_string "$INDIVIDUAL_DEPENDENCY" "$delimiter"))
    CURRENT_VERSION=${DELIMITED_DEPENDENCY[2]}

    if [ -z "$CURRENT_VERSION" ]; then
        # Find current version using gradlew command
        if [ -n "$LIBRARY" ]; then
            echo "Finding version using 'gradlew <library>:dependencies command'"
            FIND_VERSION=$(./gradlew $LIBRARY:dependencies | grep -i ""$individual_dependency" -> " | cut -d ">" -f2 | sed 's/ //g' | sed -n '1p')
            echo "Found version: $FIND_VERSION"
            if [ -n "$FIND_VERSION" ]; then
                INDIVIDUAL_DEPENDENCY="$individual_dependency:$FIND_VERSION"
                delimiter=":"
                DELIMITED_DEPENDENCY=($(delimit_string "$INDIVIDUAL_DEPENDENCY" "$delimiter"))
                dependency_xml=$(create_dependency_xml "${DELIMITED_DEPENDENCY[@]}")
                CURRENT_VERSION="${DELIMITED_DEPENDENCY[2]}"
            fi
        fi
    fi
    echo "Current Version: $CURRENT_VERSION"

    LATEST_VERSION=""
    # [BETA]: Fetch Latest version using alternative approach. This is applicable in those case where dependency has its own repository and metadata doesn't contain latest version info.
    if [ "$individual_dependency" == "$ALTERNATIVE_SDK" ] && [ -n "$ALTERNATIVE_URL" ]; then
        echo "Following alternative approach to fetch the url"
        LATEST_VERSION=($(alternative_approach "$ALTERNATIVE_URL"))
    fi
    # Default approach to fetch the latest version
    if [ -z "$LATEST_VERSION" ]; then
        LATEST_VERSION=$(echo "$OUTDATED_DEPENDENCY" | cut -d ">" -f2 | sed 's/ //g' | sed -n '1p')
    fi

    if [ -n "$CURRENT_VERSION" ] && [ -z "$LATEST_VERSION" ]; then
        echo "Unable to detect the latest version. Either pass the repository url for $individual_dependency dependency as input 'repository-urls:<REPOSITORY_URL>', or, try passing 'alternative-dependency-lookup:"$individual_dependency"' and its full repository url 'alternative-dependency-lookup-url:<FULL_REPOSITORY_URL>' as inputs."
    else
        echo "Latest version: $LATEST_VERSION"
    fi

    if [ -n "$LATEST_VERSION" ]; then
        HAS_OUTDATED_DEPENDENCIES="true"
        GENERATED_BODY="Update the "$individual_dependency" dependency from the current version $CURRENT_VERSION to the latest version $LATEST_VERSION."
        echo "$GENERATED_BODY"
        body+=("$GENERATED_BODY")
    fi
done

edit_issues() {
    local issues="$1"
    local title="$2"
    local body="$3"

    while read item; do
        i_title=$(jq -r '.title' <<<"$item")
        i_number=$(jq -r '.number' <<<"$item")

        if [ "$i_title" == "$title" ]; then
            echo "Edit existing issue"
            gh issue edit "$i_number" --body "$body"
            ISSUE_URL=$(gh issue view "$i_number" --json url | jq '.[]')
            return
        fi
    done <<<"$(echo "$issues" | jq -c -r '.[]')"
}

create_new_issue() {
    echo "Creating new issue"

    # Create a label
    if [ -n "$LABELS" ]; then
        echo "Creating new $LABELS label with the $COLOR color"
        $(gh label create --force "$LABELS" --description "Dependency is outdated" --color "$COLOR")
    fi
    # Create a new issue
    ISSUE_URL=$(gh issue create -a "$ASSIGNEE" -b "$BODY" -t "$TITLE" --label "$LABELS")
}

if [ -z "$TITLE" ]; then
    echo "Since title of the issue is not present, issue will not be created. To create the issue at least provide the title."
    export ISSUE_URL="" HAS_OUTDATED_DEPENDENCIES
else

    # Create a sinle body delimited with newlines
    body=$(
        IFS=$'\n'
        echo "${body[*]}"
    )

    # If BODY input is not provided
    if [ -z "$BODY" ]; then
        BODY="$body"
    fi

    # Create or edit existing issue
    if [ "$HAS_OUTDATED_DEPENDENCIES" == "true" ]; then

        # Construct json array containing title and number
        issues=$(gh issue list --search "$TITLE" --json title,number)

        # Edit the issue and get the issue url
        edit_issues "$issues" "$TITLE" "$BODY"
        # If issue url already exists
        if [ -n "$ISSUE_URL" ]; then
            echo "Issue exist and its URL is: $ISSUE_URL"
            export ISSUE_URL HAS_OUTDATED_DEPENDENCIES
        else
            # Issue doesn't exist!
            create_new_issue
            echo "New issue is created and its URL is: $ISSUE_URL"
            export ISSUE_URL HAS_OUTDATED_DEPENDENCIES
        fi
    else
        echo "No outdated dependency detected"
        export ISSUE_URL="" HAS_OUTDATED_DEPENDENCIES
    fi
fi
