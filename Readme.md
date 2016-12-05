# d3.Timeslider

d3.Timeslider is a time slider based on the [D3.js](http://d3js.org) javascript
library. It is written in [CoffeeScript](http://coffeescript.org) and
[Less](http://lesscss.org)

The software is licensed under a MIT compatible license, for more information see
[License](License).

For a list of recent changes, please see the [Changelog](Changelog).

## Usage

Include the JavaScript and CSS files (and [D3.js](http://d3js.org/) as
D3.Timeslider depends on it) and then instantiate a new slider like in the
following snippet.

You can download the latest version of D3 directly from
[d3js.org/d3.v3.zip](http://d3js.org/d3.v3.zip)

If you want to display datasets loaded from an EOWCS server, you also need
to include [libcoverage.js](https://github.com/EOX-A/libcoverage.js).

## Options

### `domain` - ` { start: <Date>, end: <Date> }`

The maximum domain of the timeslider. When `constrain` is set, it is not
possible to zoom/pan outside of this domain.

### `brush` - ` { start: <Date>, end: <Date> }`

The initial selection.

### `display` - ` { start: <Date>, end: <Date> }`

The initially displayed interval. This defaults to the `domain`.

### `ticksize` - `Number`

The height of the displayed ranges or the diameter of the displayed dots.

### `debounce` - `Number`

The time (in milliseconds) to wait between accessing the sources `fetch`
function.

### `brushTooltip` - `boolean`

Whether or not to display the brush tooltips. Defaults to `false`.

### `tooltipFormatter` - `function`

This function is invoked when a tooltip is to be displayed for a record. It is
passed the record, an `Array` in the following form: `start`, `end`, and
`params`. By default, a function is used that displays either the `id` or `name`
property (in that order).

When the function returns a falsy value, then no tooltip is displayed.

### `constrain` - `boolean`

When set, the viewable interval is constrained to the `domain`.

### `selectionLimit` - `String|Number`

When set, this limits the maximum interval allowed to brush. This can either be
a number (number of seconds) or a
[ISO8601 duration](https://en.wikipedia.org/wiki/ISO_8601#Durations).

### `displayLimit` - `String|Number`

When set, this limits the maximum interval allowed to display. This can either be
a number (number of seconds) or a
[ISO8601 duration](https://en.wikipedia.org/wiki/ISO_8601#Durations).

### `recordFilter` - `function`

A function to be called for each record with the following parameters: `record`
(an array: `start`, `end`, and `params`) and the `dataset`. When the function
returns a truthy value, the record is displayed whole, and hollow otherwise.

### `datasets` - `[ {...}, ]`

An array of dataset definitions (objects) with the following layout

 - `id`: The ID of the dataset. This is used in events and callbacks
 - `color`: The color to display the dataset. Anything possible for CSS works here
 - `lineplot`: Whether this dataset will be displayed as a line
 - `histogramThreshold`: Sets the threshold, when this dataset will be displayed
   in a quantized manner.
 - `sourceParams`: Anything you want to pass to the source function.
 - `records`: The records for this dataset. When the records are set this way,
   the dataset is static, and does not change.
 - `source`: Either a function or an object with a `fetch` method. This
   function/method is passed the following arguments: `start`, `end`,
   `sourceParams` and a `callback`. The callback is expected to be called with
   an array of either:
     - single `Dates`
     - an `Array` of
       - one `Date` and parameters (or a single value for `lineplots`)
       - two `Date`s
       - two `Date`s and parameters

   The parameters are used for the `recordFilter` and to display the tooltip on
   the mouseover: either the `id` or `name` properties are used when available.
 - `cacheRecords`: Use an internal cache to only request intervals that have not
   been requested before.
 - `cacheIdField`: Field to check the equality of records. This is necessary
   when two intervals of records need to be merged. When not set, then the time
   stamps of the records are used.

## Public API

### `hide` / `show`

Hide/show the timeslider (using the CSS `display` property).

### `domain` - `start`, `end`

Sets the domain to the new start/end. This method redraws the timeslider.

### `select` - `start`, `end`

Sets the selection of the timeslider.

### `center` - `start`, `end`

Immediatly show the given interval. Redraws.

### `zoom` - `start`, `end`

Zoom to the given interval over a small amount of time. Redraws in the transition.

### `addDataset` - `definition`

Adds a new dataset by definition. See the initial options for the layout. This
starts the reloading of the dataset.

### `removeDataset` - `id`

Remove a dataset by its ID. Redraws.

### `hasDataset` - `id`

Returns `true` when the dataset with the `id` exists.

### `reset`

Reset the view to the `domain` using `zoom`.

### `setBrushTooltip` - `boolean`

Enable/disable the brush tooltip.

### `setBrushTooltipOffset`

Set the pixel offsets of the brush tooltips.

### `setRecordFilter` - `function`

Set the `recordFilter`. See the options for details. Redraws.

### `setTooltipFormatter` - `function`

Sets the tooltip formatting function.

## Events raised

The timeslider raises several custom events. All arguments are stored in the
events `detail` property.

### `selectionChanged`

This event is emitted when the user has finished brushing a new selection. The
details are:

  - `start`: the new start time of the selection
  - `end`: the new end time of the selection

### `displayChanged`

This event is emitted after zooming or panning the timeslider. The
details are:

  - `start`: the new start time of the viewable interval
  - `end`: the new end time of the viewable interval

### `recordMouseover` / `recordMouseout` / `recordClicked`

These events are raised when a record is hovered, stopped hovering or clicked.
The details always include:

  - `dataset`: the dataset ID
  - `start`: the start time of the record
  - `end`: the end time of the record
  - `params`: optional record parameters when available

### `binMouseover` / `binMouseout` / `binClicked`

These events are raised when a bin of a histogram dataset is hovered, stopped
hovering or clicked. The details always include:

  - `dataset`: the dataset ID
  - `start`: the start time of the histogram bin
  - `end`: the end time of the histogram bin
  - `bin`: the array of records in that bin

## Available sources

### EO-WCS - `EOWCSSource`

This source uses [libcoverage.js](https://github.com/EOX-A/libcoverage.js) to
send `DescribeEOCoverageSet` requests to the specified EO-WCS server. The result
is parsed for all entailed coverages and their respective start/end times. The
record params include the coverages EOID which is used as the `id` for display
in the tooltip and the events.

This source allows the following parameters:

  - `url`: The URL of the WCS server
  - `eoid`: The EO-ID of the collection or coverage to perform the request on

### EOxServer WPS - `EOxServerWPSSource`

This source is specialized to access the `getTimeData` Process, that ships with
EOxServer. The response format is a CSV file, which is parsed. Sources of this
type accept the following parameters:

  - `url`: The URL of the EOxServer WPS instance.
  - `eoid`: The ID of the collection to query.

### WMS - `WMSSource`

The `WMSSource` fetches the WMS Capabilities of a server to parse the `time`
dimension of a specific layer to produce the time-marks. Capabilities responses
are globally cached. The source accepts the following parameters:

  - `url`: The URL of the WMS endpoint.
  - `layer`: The layer name.

This source is somewhat limited by the underlying protocol and is thus not able
to subset the records on a request basis and cannot provide additional metadata
(such as record ID) to display as a tooltip or provide in timeslider events.

## Example
An example on how to use it is provided below.

```html
<!-- libcoverage.js-->
<script src="dependencies/libcoverage.js/libcoverage.min.js" charset="utf-8"></script>

<!-- TimeSlider -->
<script src="build/d3.timeslider.js"></script>
<script src="build/d3.timeslider.plugins.js"></script>
<link href="build/d3.timeslider.css" rel="stylesheet" type="text/css" media="all" />
<script>
  window.addEventListener('load', function() {
    // Initialize the TimeSlider
    slider = new TimeSlider(document.getElementById('d3_timeslider'), {
      debounce: 50,
      domain: {
        start: new Date("2012-01-01T00:00:00Z"),
        end: new Date("2013-01-01T00:00:00Z"),
      },
      brush: {
        start: new Date("2012-01-05T00:00:00Z"),
        end: new Date("2012-01-10T00:00:00Z")
      },
      datasets: [
        {
          id: 'img2012',
          color: 'red',
          data: function(start, end, callback) {
            return callback('img2012', [
              [ new Date("2012-01-01T12:00:00Z"), new Date("2012-01-01T16:00:00Z") ],
              [ new Date("2012-01-02T12:00:00Z"), new Date("2012-01-02T16:00:00Z") ],
              new Date("2012-01-04T00:00:00Z"),
              new Date("2012-01-05T00:00:00Z"),
              [ new Date("2012-01-06T12:00:00Z"), new Date("2012-01-26T16:00:00Z") ],
            ]);
          }
        }
      ]
    });

    // Register a callback for changing the selected time period
    document.getElementById('d3_timeslider').addEventListener('selectionChanged', function(e){
      console.log("Custom event handler on the time slider");
      console.log(e.detail);
    });

    // Change the TimeSlider domain, or the selected interval, then reset the
    // TimeSlider to it's initial state
    slider.domain(new Date("2011-01-01T00:00:00Z"),  new Date("2013-01-01T00:00:00Z"));
    slider.select(new Date("2011-02-01T00:00:00Z"),  new Date("2013-02-08T00:00:00Z"))
    slider.reset();

    // Add a new dataset and remove another one
    slider.addDataset({
      id: 'fsc',
      color: 'green'
      data: new TimeSlider.Plugin.EOWCS({ url: 'http://neso.cryoland.enveo.at/cryoland/ows', eoid: 'daily_FSC_PanEuropean_Optical', dataset: 'fsc' })
    });
    slider.addDataset({
      id: 'asar',
      color: 'purple',
      data: new TimeSlider.Plugin.WMS({ url: 'http://data.eox.at/instance01/ows', eoid: 'ASAR_IMM_L1_view', dataset: 'asar' })
    })
    slider.removeDataset('img2012');
)
  }, false);
</script>
```

## Development

Install development dependencies, and start grunt via the following two commands.

```sh
npm install
grunt watch
```

You can then open the [preview](preview.html) page and any changes to the
CoffeeScript and Less files will be automatically compiled and reloaded in the
browser.

To lint the CoffeeScript source run the following command.

```sh
grunt lint
```
