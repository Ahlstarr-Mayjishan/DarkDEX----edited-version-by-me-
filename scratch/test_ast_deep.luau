-- Test Case 1: Inside a function body (should resolve run -> loadstring and flag dynamic execution)
local function bypass(payload)
    local run = loadstring
    run(payload)
end

-- Test Case 2: Inside a control structure block (should resolve run -> loadstring and flag dynamic execution)
if true then
    local run = loadstring
    run(payload)
end

-- Test Case 3: Using table alias mapping (should resolve tbl.exec -> loadstring and flag dynamic execution)
local tbl = { exec = loadstring }
tbl.exec(payload)

-- Test Case 4: Using table property assignment (should resolve tbl2.exec -> loadstring and flag dynamic execution)
local tbl2 = {}
tbl2.exec = loadstring
tbl2.exec(payload)

-- Test Case 5: Webhook Constant Folding (should fold and flag Discord Webhook Leak)
local url = "discord" .. ".com/api/webhooks/12345"
