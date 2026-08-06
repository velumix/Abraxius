local allData = {}

for _, module in script:GetChildren() do
    local requiredModule = require(module)
    allData[requiredModule._id] = requiredModule
end


return allData