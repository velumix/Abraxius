local KnifeImages = {}

KnifeImages.BY_ID = {
	fireworkfalcon = "rbxassetid://111396798633787",
	freedomstorch = "rbxassetid://118749445191921",
	paintball = "rbxassetid://133155704379810",
	libertywing = "rbxassetid://96780642313042",
	patrioticphantom = "rbxassetid://108472938973821",
	rocketsroar = "rbxassetid://116384493916705",
	independenceblade = "rbxassetid://79771984459597",
	military = "rbxassetid://84098236790843",
	shopping = "rbxassetid://119080558000108",
	intercoolerpc = "rbxassetid://109641775876042",
	sparklingdagger = "rbxassetid://81977673487235",
	eaglesfire = "rbxassetid://124548560248168",
	battlebanner = "rbxassetid://99069763490574",
	pyramid = "rbxassetid://139594798517075",
}

function KnifeImages.get(skinId)
	return skinId and KnifeImages.BY_ID[skinId] or nil
end

return KnifeImages
