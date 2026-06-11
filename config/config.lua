Config = {}

Config.Locale = 'eng'
Config.Debug  = false

-- Permission required to open the studio. The check adapts to your framework:
--   RSG        -> permission level   (RSGCore HasPermission)
--   VORP       -> character group    (getUsedCharacter.group)
--   Standalone -> ACE object         (add_ace group.admin admin allow)
Config.Permission = 'admin'

-- Chat command that opens the menu
Config.Command = 'particlestudio'

-- Maximum raycast distance during placement (metres)
Config.PlacementDistance = 50.0

-- Height change per scroll tick (metres)
Config.HeightStep = 0.1

-- Replay interval for NonLooped effects synced to all clients (ms)
Config.NonLoopedInterval = 800

-- Replay interval for the local NonLooped preview only (ms)
Config.PreviewNonLoopedInterval = 400

-- Default scale when an effect is first selected
Config.DefaultScale = 1.0

-- Default duration in seconds; 0 = permanent
Config.DefaultDuration = 0

-- ─────────────────────────────────────────────
-- Key bindings — use RDR3 INPUT_ control names
-- ─────────────────────────────────────────────
Config.Keys = {
    Enter       = 'INPUT_ENTER',
    Cancel      = 'INPUT_INTERACT_ANIMAL',    -- G key
    ScrollUp    = 'INPUT_SELECT_NEXT_WEAPON', -- scroll wheel up  / E
    ScrollDown  = 'INPUT_SELECT_PREV_WEAPON', -- scroll wheel down / Q
    RotateLeft  = 'INPUT_FRONTEND_LEFT',      -- ← arrow — yaw left
    RotateRight = 'INPUT_FRONTEND_RIGHT',     -- → arrow — yaw right
    RotateUp    = 'INPUT_FRONTEND_UP',        -- ↑ arrow — pitch up
    RotateDown  = 'INPUT_FRONTEND_DOWN',      -- ↓ arrow — pitch down
    FreeCam     = 'INPUT_CONTEXT_B',          -- F key  — toggle free camera
    MoveUp      = 'INPUT_JUMP',               -- Space  — raise camera / effect height
    MoveDown    = 'INPUT_SPRINT',             -- Shift  — lower camera / effect height
}

-- Free camera movement speed (metres per frame at ~60 fps)
Config.FreeCamSpeed = 0.3

-- Degrees rotated per arrow-key tick
Config.RotationStep = 5.0

-- ─────────────────────────────────────────────
-- Notification helper — used by both client and server.
-- Uses the built-in NUI toasts; swap the body below
-- if you prefer your own notification system.
-- ─────────────────────────────────────────────
local _isServer = IsDuplicityVersion()

function Notify(message, timer, ntype, source)
    timer = timer or 5000
    ntype = ntype or 'info'
    if _isServer then
        TriggerClientEvent('gu-particlestudio:client:notify', source, message, timer, ntype)
    else
        SendNUIMessage({ action = 'notify', message = message, ntype = ntype, timer = timer })
    end
end
