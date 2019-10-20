// TODO
function setLoadingStates(elementType) {
    $(elementType).each(function() {
        if ($(this).attr('id')) {
            // Only set loading state for element who have an id (the
            // repository name)
            $(this).text("Getting descriptions...");
        }
    });
}

// Load and set project descriptions from a Github repository 
function loadRepositoryDescriptions(user, elementType) {
    $.getJSON({
        url: "https://api.github.com/users/" + user + "/repos",
        jsonp: true,
        method: "GET",
        dataType: "json",
        success: function(result) {
            $(document).ready(setRepositoryDescriptions(result, elementType));
        }
    }).fail(function() {
        console.log("Failed to get repository descriptions");
    });
}

// Set repository descriptions for each project
function setRepositoryDescriptions(descriptions, elementType) {
    $(elementType).each(function() {
        var repoName = $(this).attr('id');
        var repoDesc = "";

        for (var i = 0; i < descriptions.length; ++i) {
            if (descriptions[i].fork === true) {
                // Skip forked repositories
                continue;
            }

            if (repoName === descriptions[i].name) {
                repoDesc = descriptions[i].description;
                break;
            }
        }

        if (repoDesc) {
            if (repoDesc[repoDesc.length - 1] !== ".") {
                repoDesc += ".";
            }

            $(this).text(repoDesc);
        }
    });
}
