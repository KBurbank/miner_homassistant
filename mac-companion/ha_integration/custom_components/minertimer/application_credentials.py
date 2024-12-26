"""Application credentials platform for MinerTimer."""
from homeassistant.components.application_credentials import AuthImplementation
from homeassistant.core import HomeAssistant
from homeassistant.helpers import config_entry_oauth2_flow

class MinerTimerOAuth2Implementation(AuthImplementation):
    """OAuth2 implementation for MinerTimer."""
    
    @property
    def name(self) -> str:
        """Name of the implementation."""
        return "MinerTimer"
    
    @property
    def domain(self) -> str:
        """Domain that is responsible for the implementation."""
        return "minertimer"
    
    async def async_generate_authorize_url(self, flow_id: str) -> str:
        """Generate authorization url."""
        return str(
            f"{self.auth_uri}"
            f"?client_id={self.client_id}"
            f"&redirect_uri={self.redirect_uri}"
            f"&response_type=code"
            f"&state={flow_id}"
        )

async def async_get_auth_implementation(
    hass: HomeAssistant, auth_domain: str, credential_type: str
) -> config_entry_oauth2_flow.AbstractOAuth2Implementation:
    """Return auth implementation."""
    return MinerTimerOAuth2Implementation(
        hass,
        auth_domain,
        {
            "client_id": "https://github.com/kburbank/minertimer-ha",
            "client_secret": "minertimer_secret",
            "auth_uri": "http://homeassistant:8123/auth/authorize",
            "token_uri": "http://homeassistant:8123/auth/token",
        },
    ) 