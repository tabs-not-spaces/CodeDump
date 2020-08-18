function Test-OddOrEven {
    [cmdletbinding()]
    param (
        [parameter(Mandatory = $true)]
        [int]$Integer
    )
    switch ($Integer % 2) {
        0 {
            return "$Integer is even"
        }
        1 {
            return "$Integer is odd"
        }
    }
}