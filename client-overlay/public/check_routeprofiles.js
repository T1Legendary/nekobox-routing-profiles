var route_profiles = [];
var route_profile_names = {};
var route_profile_catalog = {};

var catalog_url = "https://raw.githubusercontent.com/T1Legendary/nekobox-routing-profiles/main/catalog.json";
var catalog_response = new HTTPResponse(catalog_url);

if (catalog_response.error === "") {
    try {
        var catalog = JSON.parse(catalog_response.text);
        if (!catalog || !Array.isArray(catalog.profiles)) {
            throw new Error("catalog.profiles is not an array");
        }

        catalog.profiles.forEach(function (item) {
            if (!item || typeof item.id !== "string" || typeof item.url !== "string") {
                return;
            }
            route_profiles.push(item.id);
            route_profile_names[item.id] = item.name || item.id;
            route_profile_catalog[item.id] = item;
        });
    } catch (error) {
        warning("Invalid routing profile catalog: " + error, translate("Download Profiles"));
    }
} else {
    warning(
        translate("Requesting profile error: %1").replace(
            "%1",
            catalog_response.error + "\n" + catalog_response.text
        ),
        translate("Download Profiles")
    );
}

function route_profile_get_json(profile) {
    var item = route_profile_catalog[profile];
    if (!item) {
        warning("Routing profile is absent from catalog: " + profile, translate("Download Profiles"));
        return "";
    }

    var response = new HTTPResponse(item.url);
    var text = response.text;
    if (response.error !== "") {
        warning(
            translate("Requesting profile error: %1").replace(
                "%1",
                response.error + "\n" + text
            ),
            translate("Download Profiles")
        );
        return "";
    }

    try {
        var rules = JSON.parse(text);
        if (!Array.isArray(rules) || rules.length === 0) {
            throw new Error("profile must be a non-empty JSON array");
        }
    } catch (error) {
        warning("Invalid routing profile " + profile + ": " + error, translate("Download Profiles"));
        return "";
    }

    info(
        translate("Requesting profile success: %1").replace(
            "%1",
            route_profile_names[profile] || profile
        ),
        translate("Download Profiles")
    );

    return [text, item.url, item.default_outbound === "proxy"];
}
