"""The MinerTimer integration."""
from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant

DOMAIN = "minertimer"

async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    """Set up MinerTimer from a config entry."""
    hass.data.setdefault(DOMAIN, {})
    
    # Create default input_number for time limit
    await hass.services.async_call(
        "input_number",
        "create",
        {
            "name": "Minecraft Time Limit",
            "min": 0,
            "max": 240,
            "step": 15,
            "mode": "slider",
            "unit_of_measurement": "minutes"
        }
    )
    
    # Create automation for daily reset
    await hass.services.async_call(
        "automation",
        "create",
        {
            "alias": "Reset Minecraft Time Daily",
            "trigger": {
                "platform": "time",
                "at": "00:00:00"
            },
            "action": {
                "service": "input_number.set_value",
                "target": {
                    "entity_id": "input_number.minecraft_time_limit"
                },
                "data": {
                    "value": 60
                }
            }
        }
    )
    
    return True 