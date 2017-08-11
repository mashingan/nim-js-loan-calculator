"use strict";

function calculate() {
  var amount = document.querySelector("#amount");
  var apr = document.querySelector("#apr");
  var years = document.querySelector("#years");
  var zipcode = document.querySelector("#zipcode");
  var payment = document.querySelector("#payment");
  var total = document.querySelector("#total");
  var totalinterest = document.querySelector("#totalinterest");

  var principal = parseFloat(amount.value);
  var interest = parseFloat(apr.value) / 100 / 12;
  var payments = parseFloat(years.value) * 12;

  var x = Math.pow(1 + interest, payments);
  var monthly = (principal * x * interest) / (x-1);

  if (isFinite(monthly)) {
    payment.innerHTML = monthly.toFixed(2);
    total.innerHTML = (monthly * payments).toFixed(2);
    totalinterest.innerHTML = ((monthly * payments) - principal).toFixed(2);

    save(amount.value, apr.value, years.value, zipcode.value);

    try {
      getLenders(amount.value, apr.value, years.value, zipcode.value);
    }
    catch (e) {
      console.log(e);
    }
    chart(principal, interest, monthly, payments);
  } else {
    payment.innerHTML = "";
    total.innerHTML = "";
    totalinterest.innerHTML = "";
    chart();
  }
}

function save(amount, apr, years, zipcode) {
  if (window.localStorage) {
    localStorage.loan_amount = amount;
    localStorage.loan_apr = apr;
    localStorage.loan_years = years;
    localStorage.loan_zipcode = zipcode;
  }
}

window.onload = function () {
  if (window.localStorage && localStorage.loan_amount) {
    document.querySelector("#amount").value = localStorage.loan_amount;
    document.querySelector("#apr").value = localStorage.loan_apr;
    document.querySelector("#years").value = localStorage.loan_years;
    document.querySelector("#zipcode").value = localStorage.loan_zipcode;
  }
};

function getLenders(amount, apr, years, zipcode) {
  if (!window.XMLHttpRequest) return;
  var ad = document.querySelector("#lenders");
  if (!ad) return;

  var url = "getlenders" +
    "?amt=" + encodeURIComponent(amount) +
    "?apr=" + encodeURIComponent(apr) +
    "?yrs=" + encodeURIComponent(years) +
    "?zip=" + encodeURIComponent(zipcode);

  var req = new XMLHttpRequest();
  req.open("GET", url);   // an HTTP GET request for the URL
  req.send(null);         // send request with no body

  req.onreadystatechange = function () {
    if (req.readyState == 4 && req.status == 200) {
      var response = req.responseText;
      var lenders = JSON.parse(response);
      var list = "";
      for (var i = 0; i < lenders.length; i++)
        list += "<li><a href='" + lenders[i].url + ">" +
          lenders[i].name + "</a>";
      ad.innerHTML = "<ul>" + list + "</ul>";
    }
  }
}

function chart(principal, interest, monthly, payments) {
  var graph = document.querySelector("#graph");
  graph.width = graph.width;

  if (arguments.length == 0 || !graph.getContext) return;

  var g = graph.getContext("2d");
  var width = graph.width, height = graph.height;

  function paymentToX(n) { return n * width / payments; }
  function amountToY(a) {
    return height - (a * height / (monthly*payments*1.05));
  }

  g.moveTo(paymentToX(0), amountToY(0));
  g.lineTo(paymentToX(payments), amountToY(monthly * payments));

  g.lineTo(paymentToX(payments), amountToY(0));
  g.closePath();
  g.fillStyle = "#f88";
  g.fill();
  g.font = "bold 12px sans-serif";
  g.fillText("Total Interest Payments", 20, 20);

  var equity = 0;
  g.beginPath();
  g.moveTo(paymentToX(0), amountToY(0));
  for (var p = 1; p <= payments; p++) {
    var thisMonthInterest = (principal-equity) * interest;
    equity += (monthly - thisMonthInterest);
    g.lineTo(paymentToX(p), amountToY(equity));
  }
  g.lineTo(paymentToX(payments), amountToY(0));
  g.closePath();
  g.fillStyle = "green";
  g.fill();
  g.fillText("Total Equity", 20, 35);

  var bal = principal;
  g.beginPath();
  g.moveTo(paymentToX(0), amountToY(bal));
  for (var p = 1; p <= payments; p++) {
    var thisMonthInterest = bal * interest;
    bal -= (monthly - thisMonthInterest);
    g.lineTo(paymentToX(p), amountToY(bal));
  }
  g.lineWidth = 3;
  g.stroke();
  g.fillStyle = "black";
  g.fillText("Loan Balance", 20, 50);

  g.textAlign = "center";
  var y = amountToY(0);
  for (var year = 1; year*12 <= payments; year++) {
    var x = paymentToX(year*12);
    g.fillRect(x-0.5, y-3, 1, 3);
    if (year == 1) g.fillText("Year", x, y-5);
    if (year % 5 == 0 && year*12 !== payments)
      g.fillText(year.toString(), x, y-5);
  }

  g.textAlign = "right";
  g.textBaseline = "middle";
  var ticks = [monthly*payments, principal];
  var rightEdge = paymentToX(payments);
  for (var i = 0; i < ticks.length; i++) {
    var y = amountToY(ticks[i]);
    g.fillRect(rightEdge-3, y-0.5, 3, 1);
    g.fillText(ticks[i].toFixed(0).toString(), rightEdge-5, y);
  }
}
