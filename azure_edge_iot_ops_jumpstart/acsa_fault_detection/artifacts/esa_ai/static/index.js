var table;
$(document).ready(function () {
    table = $('#file-table').DataTable({
        responsive: true,
        order: [[2, 'desc']]
    });
});

$(function () {
    setInterval(function () {
        $.getJSON('/data', function (data) {
            table.clear().draw();
            data.files.forEach(function(file) {
                table.row.add([
                  file.name,
                  parseInt(file.size/1024),
                  new Date(file.modified * 1000).toLocaleString()
                ]).draw(false);
              });
        });
    }, 2500);
});