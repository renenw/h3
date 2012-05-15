var month_names_long = new Array("January", "February", "March", 
"April", "May", "June", "July", "August", "September", 
"October", "November", "December");

var month_names_short = new Array("Jan", "Feb", "Mar",
"Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec");

var day_names_long = new Array("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday");
var day_names_short = new Array("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat");


function format_date_time(value) {
  d = new Date(value);
  return day_names_short[d.getUTCDay()] + " " + d.getUTCDate() + " " + month_names_short[d.getUTCMonth()] + " " + d.getUTCFullYear() + ", " + (d.getUTCHours()>12 ? d.getUTCHours()-12 : d.getUTCHours() ) + ":" + 
              (d.getUTCMinutes()<10 ? "0" : "") + d.getUTCMinutes() + " " + (d.getUTCHours()>11 ? "PM" : "AM");
}

function Mini_Chart(container, caption) {

  this.container = container;
  this.caption = caption;

  this.plot = function(series) {
    this.chart = new Highcharts.Chart({
         chart: { renderTo: this.container },
         title: {
            text: this.caption
         },
         legend: { enabled: false },
         credits: { enabled: false },
         xAxis: {
           type: 'datetime',
         },
         yAxis: {
            title: {
               text: null
            }
         },
         tooltip: {
           formatter: function() {
                   return '<b>'+ this.series.name +'</b><br/>'+
               format_date_time(this.x) +': '+ this.y;
           }
         },
         series: series
      });

  }

} 
