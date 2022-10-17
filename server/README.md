<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta http-equiv="X-UA-Compatible" content="IE=edge" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Document</title>

    <style>
      button {
        background-color: transparent;
        border: 1px solid navy;
        padding: 20px;
        font-size: 1.4rem;
      }
      button:hover {
        background-color: navy;
        border: none;
        color: white;
        transition: 0.3s linear;
      }
    </style>
  </head>
  <body>
    <button>CLICK ME!</button>
    <div class="container"></div>
  </body>

  <script>
    buttonClick = function () {
      const element = document.createElement("p");
      element.innerHTML = "click";
      let container = document.querySelector(".container").appendChild(element);
    };
    document.querySelector("button").onclick = buttonClick;
  </script>
</html>
