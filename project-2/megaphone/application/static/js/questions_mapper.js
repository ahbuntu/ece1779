/**
 * Created by ahmadul.hassan on 2015-04-01.
 */

$().ready(function() {
    displayMap();
    displayQuestionMarkers();
});

var map;
function displayMap() {
    var mapCanvas = document.getElementById('map-canvas');
    var mapOptions = {
      center: new google.maps.LatLng(43.7182713,-79.3777061), //Toronto coords from google maps
      zoom: 11,
      mapTypeId: google.maps.MapTypeId.ROADMAP
    }
    map = new google.maps.Map(mapCanvas, mapOptions);
    displayQuestionMarkers();

}
//google.maps.event.addDomListener(window, 'load', initialize);

function displayQuestionMarkers() {
    $.getJSON($SCRIPT_ROOT + '/_get_questions', {
        //values of 0 returns all questions
        lat: 0,
        lon: 0,
        radius: 0
    }, function(data) {
        var questions = data.result;
        for (var idx in questions) {
            var questionMarkerLatLng = new google.maps.LatLng(questions[idx].location.lat,
                                                                questions[idx].location.lon);
            //alert(questions[idx].content);
            var marker = new google.maps.Marker({
                position: questionMarkerLatLng,
                map: map,
                title:questions[idx].content
            });
        }
        //var test = JSON.stringify(questions);
    });
}

