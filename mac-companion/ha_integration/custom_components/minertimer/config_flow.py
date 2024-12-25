"""Config flow for MinerTimer integration."""
from homeassistant import config_entries
from homeassistant.core import HomeAssistant
import voluptuous as vol

DOMAIN = "minertimer"

class MinerTimerConfigFlow(config_entries.ConfigFlow, domain=DOMAIN):
    """Handle a config flow for MinerTimer."""
    
    VERSION = 1
    
    async def async_step_user(self, user_input=None):
        """Handle the initial step."""
        if user_input is not None:
            return self.async_create_entry(
                title="MinerTimer",
                data={}
            )

        return self.async_show_form(
            step_id="user",
            data_schema=vol.Schema({})
        ) 