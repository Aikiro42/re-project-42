# Ideas guy
- Weapons are moddable like Project 45
- base:
	- katana
	- scythe
	- greatsword
	- longsword
	- stlietto
	- machete
	- khopesh
	- kris
	- dagger
	- spear
	- staff
	- polearm
	- lance
- Weapons have the following mod slots:
	- blade (visual),
	- handle (visual),
	- guard (visual),
	- stance
	- Red Ability
	- Blue Ability
	- Yellow Ability
	- Passive

## Primary Ability:
- re-implemented vanilla melee ability 
- tapping shift causes the player to dodge

## Alt Ability:
- PGR-esque combo system:
  - three states: red, blue and yellow
	- idle: red
	- crouching: blue
	- mid-air: yellow
- activated either via right-clicking or shift-right-clicking

# Implementation

## Primary Ability
```
Stance: {
	"weaponRotation": float,
	"armRotation": float,
	"weaponAngularVelocity": float,
	"armAngularVelocity": float,
	...
	"duration": float,
	
	"velocity": [float, float],  // optional
	"swoosh": string<ImagePath> // optional
	"damagePoly": Poly // optional
}
```
```
{
	"comboDamageMultipliers": {
		"slash1": 1,
		"slash2": 0.5,
		...
	}

	"comboSteps": {
		"idle": {
			"weaponRotation": 0,
			"armRotation": 0,
			"timeout": 10,
			"sequence": Stance
		},
		
		//
		"slash1": {
		
			"sequence": {
				"windup": Stance,
				"slash": Stance,
				"cooldown": Stance
			},
			
			"next": {
				"ground": {
					"default": "slash2",
					"N": "slash2",
					"NE": "slash2",
					"E": "slash2",
					"SE": "slash2",
					"S": "slash2",
					"SW": "slash2",
					"W": "slash2",
					"NW": "slash2",
				},
				"midair": {
					...
				}
			}
		}
	}
}
```