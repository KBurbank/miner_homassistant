from aiohttp import web
import voluptuous as vol
from homeassistant.const import ATTR_ENTITY_ID
import logging

class MinerTimer:
    def __init__(self, hass):
        self.hass = hass
        self.processes = {}  # Track processes across clients
        self.played_time = {}  # Track played time per user/process
        
    async def handle_process_update(self, request):
        """Handle updates from Mac clients about process state"""
        data = await request.json()
        client_id = data['client_id']
        process = data['process']
        state = data['state']
        
        # Update process state
        self.processes[client_id] = {
            'process': process,
            'state': state,
            'last_update': datetime.now()
        }
        
        # Check limits and return action
        action = await self.check_limits(client_id)
        return web.json_response({'action': action})

    async def check_limits(self, client_id):
        """Check time limits and return required action"""
        process = self.processes[client_id]
        limit = await self.get_limit(client_id)
        played_time = self.played_time.get(client_id, 0)
        
        if played_time >= limit:
            return 'suspend'
        return 'continue' 