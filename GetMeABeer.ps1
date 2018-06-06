Add-Type -AssemblyName System.speech
$HeyDylan = New-Object System.Speech.Synthesis.SpeechSynthesizer
$HeyDylan.Speak("I WANT A BEER!. STEVEN, GIVE ME A BEER!")
$HeyDylan.Dispose()