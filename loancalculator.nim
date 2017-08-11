import dom, jsffi, math, json

when not defined(js):
  {.error: "This module only works on the JavaScript platform".}

{.emit: """/*TYPESECTION*/
"use strict";
""".}

type
  #XMLHttpRequest {.importc: "window.XMLHttpRequest", nodecl.} = js
  XMLHttpRequest = ref object
    readyState {.importc.}: cint
    status {.importc.}: cint
    responseText {.importc.}: cstring
    onreadystatechange: proc()
  CanvasRenderingContext2D {.importc.} = js

proc toFixed(x: SomeNumber, y: int): cstring {.importcpp, nodecl.}
proc getContext(canvas: js | Element, whatd: cstring): CanvasRenderingContext2D
  {.importcpp, nodecl.}

#proc getValue(el: Element): cstring {.importcpp, nodecl.}


proc consolelog(str: cstring) {.importc: "console.log", varargs.}

var localStorage {.importc: "window.localStorage", nodecl.}: js

proc newXmlHttpRequest(): XMLHttpRequest
  {.importcpp: "new XMLHttpRequest(@)".}

proc open(req: var XMLHttpRequest, meth, uri: cstring) {.importcpp.}
proc send(req: var XMLHttpRequest, obj: js = nil) {.importcpp.}

proc save(amount, apr, years, zipcode: float) =
  if not (localStorage == nil):
    localStorage.loan_amount = amount
    localStorage.loan_apr = apr
    localStorage.loan_years = years
    localStorage.loan_zipcode = zipcode

proc getLenders(amount, apr, years, zipcode: float) =
  var ad = document.querySelector("#lenders".cstring)
  if ad.isNil: return

  var url: cstring = "getlenders" &
    "?amt=" & $encodeURIComponent($amount) &
    "?apr=" & $encodeURIComponent($apr) &
    "?yrs=" & $encodeURIComponent($years) &
    "?zip=" & $encodeURIComponent($zipcode)

  var req = newXmlHttpRequest()
  req.open("GET".cstring, url)
  req.send()

  req.onreadystatechange = proc() =
    consolelog "req.readyState: ", req.readyState
    consolelog "req.status: ", req.status
    if req.readyState == 4 and req.status == 200:
      var
        response = req.responseText
        lenders = parseJson($response)
        list = ""
      for i in 0 ..< lenders.len:
        list &= "<li><a href='" & lenders[i]["url"].getStr & ">" &
          lenders[i]["name"].getStr & "</a>"
      ad.innerHTML = ("<ul>" & list & "</ul>").cstring

proc chart(principal, interest, monthly, payments: float) =
  template getHW(x: Element, field: untyped, back: typedesc): untyped =
    `x`.toJs.`field`.to(back)

  var graph = document.querySelector("#graph".cstring)
  graph.toJs.width = graph.toJs.width

  var
    g = graph.getContext "2d".cstring
    width = graph.getHW(width, int)
    height = graph.getHW(height, int)

  consolelog "graph: ", graph
  consolelog "g: ", g
  template paymentToX(n: SomeNumber): untyped =
    n.float * width.float / payments.float

  template amountToY(a: SomeNumber): untyped =
    height.float - (a.float * height.float / (monthly*payments*1.05))

  g.clearRect(0, 0, width, height)
  g.moveTo(paymentToX(0), amountToY(0))
  g.lineTo(paymentToX(payments), amountToY(monthly * payments))

  g.lineTo(paymentToX(payments), amountToY(0))
  g.closePath()
  g.fillStyle = "#f88".cstring
  g.fill()
  g.font = "bold 12px sans-serif".cstring
  g.fillText("Total Interest Payments".cstring, 20, 20)

  var equity = 0.0
  g.beginPath()
  g.moveTo(paymentToX(0), amountToY(0))
  var p = 1
  while p.float <= payments:
    var thisMonthInterest = (principal - equity) * interest
    equity = equity + (monthly - thisMonthInterest)
    g.lineTo(paymentToX(p), amountToY(equity))
    inc p
  g.lineTo(paymentToX(payments), amountToY(0))
  g.closePath()
  g.fillStyle = "green".cstring
  g.fill()
  g.fillText("Total Equity".cstring, 20, 35)

  var bal = principal
  g.beginPath()
  g.moveTo(paymentToX(0), amountToY(bal))
  p = 1
  while p.float <= payments:
    var thisMonthInterest = bal * interest
    bal = bal - (monthly - thisMonthInterest)
    g.lineTo(paymentToX(p), amountToY(bal))
    inc p
  g.lineWidth = 3
  g.stroke()
  g.fillStyle = "black".cstring
  g.fillText("Loan Balance".cstring, 20, 50)

  g.textAlign = "center".cstring
  var y = amountToY(0)
  var year = 1
  while (year*12).float <= payments:
    var x = paymentToX(year*12)
    g.fillRect(x-0.5, y-3, 1, 3)
    if year == 1: g.fillText("Year".cstring, x, y-5)
    if year mod 5 == 0 and (year*12).float != payments:
      g.fillText($year, x, y-5)
    inc year

  g.textAlign = "right".cstring
  g.textBaseline = "middle".cstring
  var ticks = [monthly*payments, principal]
  var rightEdge = paymentToX(payments)
  for i in 0 ..< ticks.len:
    var y = amountToY(ticks[i])
    g.fillRect(rightEdge-3, y-0.5, 3, 1)
    g.fillText($(ticks[i].toFixed(0)), rightEdge-5, y)

proc calculate*() {.exportc.} =
  template getValue(x: untyped): untyped =
    `x`.toJs.value.to(cstring)

  var
    amount = document.querySelector("#amount".cstring)
    apr = document.querySelector("#apr".cstring)
    years = document.querySelector("#years".cstring)
    zipcode = document.querySelector("#zipcode".cstring)
    payment = document.querySelector("#payment".cstring)
    total = document.querySelector("#total".cstring)
    totalinterest = document.querySelector("#totalinterest".cstring)

    principal = amount.getValue.parseFloat
    interest = parseFloat(apr.getValue) / 100 / 12
    payments = parseFloat(years.getValue) * 12

    x = pow(1+interest, payments)
    monthly = (principal * x * interest) / (x-1)

  consolelog "principal: ", principal
  consolelog "interest: ", interest
  consolelog "payments: ", payments

  if monthly.isFinite:
    payment.innerHTML = monthly.toFixed 2
    total.innerHTML = (monthly * payments).toFixed 2
    totalinterest.innerHTML = ((monthly * payments) - principal).toFixed 2

    var
      amountval = amount.getValue.parseFloat
      aprval = apr.getValue.parseFloat
      yearsval = years.getValue.parseFloat
      zipcodeval = zipcode.getValue.parseFloat

    save(amountval, aprval, yearsval, zipcodeval)
    try:
      getLenders(amountval, aprval, yearsval, zipcodeval);
    except:
      consolelog getCurrentExceptionMsg()

    chart(principal, interest, monthly, payments)
  else:
    payment.innerHTML = "".cstring;
    total.innerHTML = "".cstring;
    totalinterest.innerHTML = "".cstring;

window.onload = proc(event: Event) =
  if localStorage != nil and localStorage.loan_amount != nil:
    consolelog "succesfully update the value"
    consolelog "loan_amount: ", localStorage.loan_amount
    consolelog "loan_apr: ", localStorage.loan_apr
    consolelog "loan_years: ", localStorage.loan_years
    consolelog "loan_zipcode: ", localStorage.loan_zipcode
    document.querySelector("#amount".cstring).toJs.value =
      localStorage.loan_amount
    document.querySelector("#apr".cstring).toJs.value =
      localStorage.loan_apr
    document.querySelector("#years".cstring).toJs.value =
      localStorage.loan_years
    document.querySelector("#zipcode".cstring).toJs.value =
      localStorage.loan_zipcode
