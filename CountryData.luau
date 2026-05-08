local CountryData = {}

-- Countries indexed by first letter
CountryData.ByLetter = {
	A = {
		{name = "Australia",     continent = "Oceania",        population = "Medium (25M)",      flagColors = {"Blue","Red","White"},               economy = "Developed",   capitalLetter = "C"},
		{name = "Argentina",     continent = "South America",  population = "Medium (45M)",      flagColors = {"Light Blue","White"},               economy = "Developing",  capitalLetter = "B"},
		{name = "Austria",       continent = "Europe",         population = "Small (9M)",        flagColors = {"Red","White"},                      economy = "Developed",   capitalLetter = "V"},
		{name = "Angola",        continent = "Africa",         population = "Medium (33M)",      flagColors = {"Red","Black"},                      economy = "Developing",  capitalLetter = "L"},
		{name = "Algeria",       continent = "Africa",         population = "Large (44M)",       flagColors = {"Green","White","Red"},              economy = "Developing",  capitalLetter = "A"},
	},
	B = {
		{name = "Brazil",        continent = "South America",  population = "Large (210M)",      flagColors = {"Green","Yellow","Blue"},            economy = "Developing",  capitalLetter = "B"},
		{name = "Belgium",       continent = "Europe",         population = "Small (11M)",       flagColors = {"Black","Yellow","Red"},             economy = "Developed",   capitalLetter = "B"},
		{name = "Bangladesh",    continent = "Asia",           population = "Large (165M)",      flagColors = {"Green","Red"},                      economy = "Developing",  capitalLetter = "D"},
		{name = "Bolivia",       continent = "South America",  population = "Small (12M)",       flagColors = {"Red","Yellow","Green"},             economy = "Developing",  capitalLetter = "S"},
		{name = "Bulgaria",      continent = "Europe",         population = "Small (7M)",        flagColors = {"White","Green","Red"},              economy = "Developing",  capitalLetter = "S"},
	},
	C = {
		{name = "Canada",        continent = "North America",  population = "Medium (38M)",      flagColors = {"Red","White"},                      economy = "Developed",   capitalLetter = "O"},
		{name = "China",         continent = "Asia",           population = "Very Large (1.4B)", flagColors = {"Red","Yellow"},                     economy = "Developing",  capitalLetter = "B"},
		{name = "Colombia",      continent = "South America",  population = "Large (50M)",       flagColors = {"Yellow","Blue","Red"},              economy = "Developing",  capitalLetter = "B"},
		{name = "Chile",         continent = "South America",  population = "Medium (19M)",      flagColors = {"Red","White","Blue"},               economy = "Developing",  capitalLetter = "S"},
		{name = "Croatia",       continent = "Europe",         population = "Small (4M)",        flagColors = {"Red","White","Blue"},               economy = "Developed",   capitalLetter = "Z"},
	},
	D = {
		{name = "Denmark",              continent = "Europe",    population = "Small (6M)",  flagColors = {"Red","White"},             economy = "Developed",   capitalLetter = "C"},
		{name = "DR Congo",             continent = "Africa",    population = "Large (90M)", flagColors = {"Blue","Red","Yellow"},     economy = "Developing",  capitalLetter = "K"},
		{name = "Dominican Republic",   continent = "Caribbean", population = "Small (11M)", flagColors = {"Blue","Red","White"},      economy = "Developing",  capitalLetter = "S"},
	},
	E = {
		{name = "Egypt",         continent = "Africa",         population = "Large (100M)",  flagColors = {"Red","White","Black"},             economy = "Developing",  capitalLetter = "C"},
		{name = "Ethiopia",      continent = "Africa",         population = "Large (115M)",  flagColors = {"Green","Yellow","Red"},            economy = "Developing",  capitalLetter = "A"},
		{name = "Ecuador",       continent = "South America",  population = "Medium (18M)",  flagColors = {"Yellow","Blue","Red"},             economy = "Developing",  capitalLetter = "Q"},
		{name = "England",       continent = "Europe",         population = "Large (56M)",   flagColors = {"White","Red"},                     economy = "Developed",   capitalLetter = "L"},
	},
	F = {
		{name = "France",        continent = "Europe",  population = "Large (67M)",   flagColors = {"Blue","White","Red"}, economy = "Developed",  capitalLetter = "P"},
		{name = "Finland",       continent = "Europe",  population = "Small (5.5M)",  flagColors = {"White","Blue"},       economy = "Developed",  capitalLetter = "H"},
		{name = "Fiji",          continent = "Oceania", population = "Small (900K)",  flagColors = {"Blue","White"},       economy = "Developing", capitalLetter = "S"},
	},
	G = {
		{name = "Germany",       continent = "Europe",        population = "Large (83M)",   flagColors = {"Black","Red","Yellow"}, economy = "Developed",  capitalLetter = "B"},
		{name = "Ghana",         continent = "Africa",        population = "Medium (31M)",  flagColors = {"Red","Gold","Green"},   economy = "Developing", capitalLetter = "A"},
		{name = "Greece",        continent = "Europe",        population = "Small (11M)",   flagColors = {"Blue","White"},         economy = "Developed",  capitalLetter = "A"},
		{name = "Guatemala",     continent = "North America", population = "Medium (17M)",  flagColors = {"Blue","White"},         economy = "Developing", capitalLetter = "G"},
	},
	H = {
		{name = "Hungary",       continent = "Europe",        population = "Small (10M)", flagColors = {"Red","White","Green"}, economy = "Developed",  capitalLetter = "B"},
		{name = "Honduras",      continent = "North America", population = "Small (10M)", flagColors = {"Blue","White"},        economy = "Developing", capitalLetter = "T"},
		{name = "Haiti",         continent = "Caribbean",     population = "Small (11M)", flagColors = {"Blue","Red"},          economy = "Developing", capitalLetter = "P"},
	},
	I = {
		{name = "India",         continent = "Asia",    population = "Very Large (1.4B)", flagColors = {"Orange","White","Green"},  economy = "Developing", capitalLetter = "N"},
		{name = "Indonesia",     continent = "Asia",    population = "Large (270M)",      flagColors = {"Red","White"},             economy = "Developing", capitalLetter = "J"},
		{name = "Italy",         continent = "Europe",  population = "Large (60M)",       flagColors = {"Green","White","Red"},     economy = "Developed",  capitalLetter = "R"},
		{name = "Iran",          continent = "Asia",    population = "Large (85M)",        flagColors = {"Green","White","Red"},     economy = "Developing", capitalLetter = "T"},
		{name = "Iraq",          continent = "Asia",    population = "Medium (40M)",       flagColors = {"Red","White","Black"},     economy = "Developing", capitalLetter = "B"},
		{name = "Ireland",       continent = "Europe",  population = "Small (5M)",         flagColors = {"Green","White","Orange"},  economy = "Developed",  capitalLetter = "D"},
	},
	J = {
		{name = "Japan",         continent = "Asia",      population = "Large (125M)", flagColors = {"White","Red"},                economy = "Developed",  capitalLetter = "T"},
		{name = "Jamaica",       continent = "Caribbean", population = "Small (3M)",   flagColors = {"Black","Gold","Green"},       economy = "Developing", capitalLetter = "K"},
		{name = "Jordan",        continent = "Asia",      population = "Small (10M)",  flagColors = {"Black","White","Green","Red"}, economy = "Developing", capitalLetter = "A"},
	},
	K = {
		{name = "Kenya", continent = "Africa", population = "Large (54M)", flagColors = {"Black","Red","Green","White"}, economy = "Developing", capitalLetter = "N"},
		{name = "Kazakhstan", continent = "Asia", population = "Medium (19M)", flagColors = {"Light Blue","Yellow"}, economy = "Developing", capitalLetter = "N"},
		{name = "Kuwait", continent = "Asia", population = "Small (4M)", flagColors = {"Green","White","Red","Black"}, economy = "Developed", capitalLetter = "K"},
		{name = "Kyrgyzstan", continent = "Asia", population = "Small (7M)", flagColors = {"Red","Yellow"}, economy = "Developing", capitalLetter = "B"},
		{name = "Kosovo", continent = "Europe", population = "Small (2M)", flagColors = {"Blue","Yellow","White"}, economy = "Developing", capitalLetter = "P"},
	},
	L = {
		{name = "Lebanon",       continent = "Asia",    population = "Small (7M)",   flagColors = {"Red","White","Green"},        economy = "Developing", capitalLetter = "B"},
		{name = "Libya",         continent = "Africa",  population = "Small (7M)",   flagColors = {"Red","Black","Green","White"}, economy = "Developing", capitalLetter = "T"},
		{name = "Luxembourg",    continent = "Europe",  population = "Small (650K)", flagColors = {"Red","White","Light Blue"},    economy = "Developed",  capitalLetter = "L"},
	},
	M = {
		{name = "Mexico",        continent = "North America", population = "Large (130M)",  flagColors = {"Green","White","Red"},          economy = "Developing", capitalLetter = "M"},
		{name = "Morocco",       continent = "Africa",        population = "Medium (37M)",  flagColors = {"Red","Green"},                  economy = "Developing", capitalLetter = "R"},
		{name = "Malaysia",      continent = "Asia",          population = "Medium (33M)",  flagColors = {"Red","White","Blue","Yellow"},  economy = "Developing", capitalLetter = "K"},
		{name = "Myanmar",       continent = "Asia",          population = "Large (55M)",   flagColors = {"Yellow","Green","Red","White"}, economy = "Developing", capitalLetter = "N"},
		{name = "Madagascar",    continent = "Africa",        population = "Medium (28M)",  flagColors = {"White","Red","Green"},          economy = "Developing", capitalLetter = "A"},
	},
	N = {
		{name = "Nigeria",       continent = "Africa",  population = "Large (210M)", flagColors = {"Green","White"},              economy = "Developing", capitalLetter = "A"},
		{name = "Norway",        continent = "Europe",  population = "Small (5M)",   flagColors = {"Red","White","Blue"},         economy = "Developed",  capitalLetter = "O"},
		{name = "Netherlands",   continent = "Europe",  population = "Medium (17M)", flagColors = {"Red","White","Blue"},         economy = "Developed",  capitalLetter = "A"},
		{name = "Nepal",         continent = "Asia",    population = "Medium (29M)", flagColors = {"Red","Blue","White"},         economy = "Developing", capitalLetter = "K"},
		{name = "New Zealand",   continent = "Oceania", population = "Small (5M)",   flagColors = {"Blue","Red","White"},         economy = "Developed",  capitalLetter = "W"},
	},
	O = {
		{name = "Oman", continent = "Asia", population = "Small (5M)", flagColors = {"Red","White","Green"}, economy = "Developed", capitalLetter = "M"},
	},
	P = {
		{name = "Pakistan",      continent = "Asia",          population = "Large (220M)",  flagColors = {"Green","White"},               economy = "Developing", capitalLetter = "I"},
		{name = "Peru",          continent = "South America", population = "Medium (32M)",  flagColors = {"Red","White"},                 economy = "Developing", capitalLetter = "L"},
		{name = "Philippines",   continent = "Asia",          population = "Large (110M)",  flagColors = {"Blue","Red","White","Yellow"}, economy = "Developing", capitalLetter = "M"},
		{name = "Poland",        continent = "Europe",        population = "Large (38M)",   flagColors = {"White","Red"},                 economy = "Developed",  capitalLetter = "W"},
		{name = "Portugal",      continent = "Europe",        population = "Small (10M)",   flagColors = {"Green","Red","Yellow"},        economy = "Developed",  capitalLetter = "L"},
	},
	Q = {
		{name = "Qatar", continent = "Asia", population = "Small (2.8M)", flagColors = {"Maroon","White"}, economy = "Developed", capitalLetter = "D"},
	},
	R = {
		{name = "Russia",        continent = "Europe/Asia", population = "Large (145M)",  flagColors = {"White","Blue","Red"},    economy = "Developing", capitalLetter = "M"},
		{name = "Romania",       continent = "Europe",      population = "Medium (19M)",  flagColors = {"Blue","Yellow","Red"},   economy = "Developing", capitalLetter = "B"},
		{name = "Rwanda",        continent = "Africa",      population = "Small (13M)",   flagColors = {"Blue","Yellow","Green"}, economy = "Developing", capitalLetter = "K"},
	},
	S = {
		{name = "Saudi Arabia",  continent = "Asia",    population = "Medium (35M)",  flagColors = {"Green","White"},                              economy = "Developed",  capitalLetter = "R"},
		{name = "South Africa",  continent = "Africa",  population = "Large (60M)",   flagColors = {"Green","Yellow","Black","Red","White","Blue"}, economy = "Developing", capitalLetter = "P"},
		{name = "Spain",         continent = "Europe",  population = "Large (47M)",   flagColors = {"Red","Yellow"},                               economy = "Developed",  capitalLetter = "M"},
		{name = "Sweden",        continent = "Europe",  population = "Small (10M)",   flagColors = {"Blue","Yellow"},                              economy = "Developed",  capitalLetter = "S"},
		{name = "Switzerland",   continent = "Europe",  population = "Small (8.5M)",  flagColors = {"Red","White"},                                economy = "Developed",  capitalLetter = "B"},
		{name = "South Korea",   continent = "Asia",    population = "Large (52M)",   flagColors = {"White","Red","Blue","Black"},                 economy = "Developed",  capitalLetter = "S"},
		{name = "Somalia",       continent = "Africa",  population = "Medium (16M)",  flagColors = {"Light Blue","White"},                        economy = "Developing", capitalLetter = "M"},
		{name = "Sudan",         continent = "Africa",  population = "Large (44M)",   flagColors = {"Red","White","Black","Green"},                economy = "Developing", capitalLetter = "K"},
	},
	T = {
		{name = "Turkey",        continent = "Europe/Asia", population = "Large (84M)",  flagColors = {"Red","White"},                   economy = "Developing", capitalLetter = "A"},
		{name = "Thailand",      continent = "Asia",        population = "Large (70M)",  flagColors = {"Red","White","Blue"},            economy = "Developing", capitalLetter = "B"},
		{name = "Tanzania",      continent = "Africa",      population = "Large (61M)",  flagColors = {"Green","Yellow","Blue","Black"},  economy = "Developing", capitalLetter = "D"},
		{name = "Tunisia",       continent = "Africa",      population = "Small (12M)",  flagColors = {"Red","White"},                   economy = "Developing", capitalLetter = "T"},
	},
	U = {
		{name = "United States", continent = "North America",  population = "Large (330M)",  flagColors = {"Red","White","Blue"},          economy = "Developed",  capitalLetter = "W"},
		{name = "Ukraine",       continent = "Europe",          population = "Large (44M)",   flagColors = {"Blue","Yellow"},               economy = "Developing", capitalLetter = "K"},
		{name = "Uganda",        continent = "Africa",          population = "Large (47M)",   flagColors = {"Black","Yellow","Red"},        economy = "Developing", capitalLetter = "K"},
		{name = "UAE",           continent = "Asia",            population = "Small (10M)",   flagColors = {"Red","Green","White","Black"}, economy = "Developed",  capitalLetter = "A"},
		{name = "Uruguay",       continent = "South America",   population = "Small (3.5M)",  flagColors = {"White","Blue","Yellow"},       economy = "Developing", capitalLetter = "M"},
	},
	V = {
		{name = "Venezuela",     continent = "South America", population = "Medium (28M)", flagColors = {"Yellow","Blue","Red"}, economy = "Developing", capitalLetter = "C"},
		{name = "Vietnam",       continent = "Asia",          population = "Large (97M)",  flagColors = {"Red","Yellow"},        economy = "Developing", capitalLetter = "H"},
	},
	W = {
		{name = "Wales", continent = "Europe", population = "Small (3M)", flagColors = {"Red","White","Green"}, economy = "Developed", capitalLetter = "C"},
	},
	Y = {
		{name = "Yemen", continent = "Asia", population = "Medium (30M)", flagColors = {"Red","White","Black"}, economy = "Developing", capitalLetter = "S"},
	},
	Z = {
		{name = "Zambia",        continent = "Africa", population = "Medium (18M)", flagColors = {"Green","Red","Black","Orange"},         economy = "Developing", capitalLetter = "L"},
		{name = "Zimbabwe",      continent = "Africa", population = "Medium (15M)", flagColors = {"Green","Yellow","Red","Black","White"}, economy = "Developing", capitalLetter = "H"},
	},
}

return CountryData
