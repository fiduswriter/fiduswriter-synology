# Fidus Writer configuration for Synology DSM.
#
# This file lives in the package's data folder (/data) and can be edited
# in the DSM window (Manage -> Settings) or with a text editor. The
# settings here are appended to Fidus Writer's base settings.

# The bridge authenticates every request with the signed-in DSM user and
# passes the identity on in headers. The bundled "synology" app trusts
# those headers (verified against the shared secret in
# /data/.bridge-secret) and logs the corresponding user in, creating the
# account on first use. DSM administrators become Fidus Writer
# administrators.
INSTALLED_APPS = [
    "user_template_manager",  # document template manager
    "book",  # book composer
    "synology",  # Synology Docker bridge SSO integration
]

MIDDLEWARE = [
    "synology.middleware.SynologyBridgeAuthMiddleware",
]

SYNOLOGY_BRIDGE_AUTH = True

# The bridge preserves the public Host header (the DSM address), which is
# not known when this package is built.
ALLOWED_HOSTS = ["*"]
