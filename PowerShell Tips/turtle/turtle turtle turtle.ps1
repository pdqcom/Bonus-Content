Install-Module Turtle

# docs: https://psturtle.com/Commands/Get-Turtle/

#region Simple Triangle
turtle "
    rotate 120
    forward 42 
    rotate 120 
    forward 42 
    rotate 120 
    forward 42
" | Save-Turtle -FilePath .\turtle\triangle.svg
Invoke-Item .\turtle\triangle.svg

#endregion


#region flower
turtle flower | Save-Turtle -FilePath .\turtle\flower.svg
Invoke-Item .\turtle\flower.svg

# Mighty Morphing Flower Rangers 🦸‍♂️🦸‍♀️
$sideCount = (3..12 | Get-Random)        
turtle Flower 50 15 $sideCount 36 morph @(
    turtle Flower 50 10 $sideCount 72
    turtle rotate (                
        Get-Random -Max 360 -Min -360
    ) Flower 50 5 $sideCount 72
    turtle Flower 50 10 $sideCount 72
) | Save-Turtle -FilePath .\turtle\MightyMorphingFlowerRangers.svg
Invoke-Item .\turtle\MightyMorphingFlowerRangers.svg


# starting to get trippy
turtle StarFlower 42 45 8 24 morph @(
    turtle StarFlower 42 45 8 24
    turtle rotate (Get-Random -Max 360) StarFlower 42 15 8 24
    turtle StarFlower 42 45 8 24
) | Save-Turtle -FilePath .\turtle\starflower.svg
Invoke-Item .\turtle\starflower.svg

#endregion flower

# I'm seeing stars, batman

turtle @('StepSpiral',3, 90, 'rotate',90 * 4) morph @(
    turtle @('StepSpiral',3, 90, 'rotate',90 * 4)
    turtle @('StepSpiral',3, 90, 'rotate',-90 * 4)
    turtle @('StepSpiral',3, 90, 'rotate',90 * 4)
) | Save-Turtle -FilePath .\turtle\stepspiral.svg
Invoke-Item .\turtle\stepspiral.svg