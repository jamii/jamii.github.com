function runway(total, spending, interest) {
  if (spending == 0) {
    return Infinity;
  }
  var years = 0;
  while (total >= spending) {
    years += 1;
    var new_total = (total - spending) * (1 + interest / 100);
    if (new_total >= total) {
      return Infinity;
    }
    total = new_total;
  }
  return years;
}

function drawContour() {
  var spendings = [...Array(101).keys()].map(s => s * 1000);
  var initials = [...Array(101).keys()].map(i => i * 10000);
  var interest = Number.parseFloat(
    document.getElementById("interest").value.replace("%", "")
  );

  if (!isNaN(interest)) {
    var data = [
      {
        x: spendings,
        y: initials,
        z: initials.map(initial =>
          spendings.map(spending => runway(initial, spending, interest))
        ),
        type: "contour",
        colorscale: "Viridis",
        contours: {
          start: 0,
          end: 100,
          size: 10
        },
        colorbar: {
          title: "Years of runway",
          titleside: "right"
        }
      }
    ];

    var layout = {
      autosize: true,
      margin: { l: 0, r: 0, t: 0, b: 0, pad: 0 },
      xaxis: { title: { text: "Annual spending" }, automargin: true },
      yaxis: { title: { text: "Initial savings" }, automargin: true }
    };

    Plotly.newPlot("contour", data, layout, {
      displayModeBar: false
    });
  }
}

window.onload = function() {
  document.getElementById("contour").innerText = "";
  document.getElementById("interest").onkeyup = drawContour;
  drawContour();
};
