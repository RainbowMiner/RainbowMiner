# validity
jQuery form validation using [validity](https://html.spec.whatwg.org/#dom-cva-validity) property.

## Getting Started
```
<script src="//code.jquery.com/jquery-3.3.1.min.js"></script>
<script src="jquery.validity.js"></script>
```

## Usage
```
$('.form')
    .validity()
    .on('submit', function(e) {
        if (!$(this).valid()) {
            e.preventDefault();
        }
    });
```

```
$('.form')
    .validity()
    .on('submit', function(e) {
        if ($(this).valid()) {
            // ...
        }
    });
```

[Examples](http://htmlpreview.github.io/?https://github.com/gustavoconci/validity/blob/master/index.html)
