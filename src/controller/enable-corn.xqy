
import module namespace cookies = "http://parthcomp.com/cookies" at "/lib/cookies.xqy";


let $state := xdmp:get-request-field("q", "off")

return if ($state eq "off") then
    let $_ := cookies:delete-cookie("RUNDMC-CORN", (), "/")
    return <off/>
else
    let $_ := cookies:add-cookie("RUNDMC-CORN", "on", current-dateTime() + xs:dayTimeDuration("P60D"), (), "/", false())
    return <on/>
