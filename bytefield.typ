// Bytefield - generate protocol headers and more
// Feel free to contribute with any features you think are missing.
// Still a WIP - alpha stage and a bit hacky at the moment

#import "@preview/tablex:0.0.6": tablex, cellx, gridx
#import "@preview/oxifmt:0.2.0": strfmt
#set text(font: "IBM Plex Mono")

#let bfcell(
  len, // lenght of the fields in bits 
  content, 
  fill: none, // color to fill the field
  height: auto, // height of the field
) = cellx(colspan: len, fill: fill, inset: 0pt)[#box(height: height, width: 100%, stroke: 1pt + black)[#content]]



#let calc_meta_data(bitboxes, row_width: 32) = {
  let bitcells = ();
  let idx = 0;

  for bb in bitboxes {
    let remaining_bits_in_current_row = row_width - calc.rem(idx, row_width);

    let (size, content, fill, ..) = bb;
    assert(type(size) == int or size == auto, message: strfmt("expected auto or integer for parameter size, found {} ", type(size)))
    // if no size was specified
    if (size == auto ) { size = remaining_bits_in_current_row; } 
    
    // update start and idx
    let start = idx;
    idx = start + size;
    // create bc
    let bc = (
      type: "bitcell",
      size: size,
      start: start,
      end: (start + size) -1,
      wrap: if (remaining_bits_in_current_row < size) { true } else { false },
      multirow: if (size > row_width and calc.rem(size, row_width) == 0) { size/row_width } else { 1 },
      fill: bb.fill,
      content: bb.content,
    )
    bitcells.push(bc);
  }

  return bitcells
}

#let bytefield(
  bits: 32, 
  rowheight: 2.5em, 
  bitheader: auto, 
  msb_first: false,
  ..fields
) = {
  // state variables
  let col_count = 0
  let cells = ()
  let row_width = bits

  // Define default behavior - show 
  if (bitheader == auto) { bitheader = "smart"}
  // create bitcells from bitboxes
  let _cells = calc_meta_data(fields.pos(), row_width: bits)
 
  // split cells 
  _cells = _cells.map(c => if (c.multirow > 1 ) { c.size = row_width; c.wrap = false; c } else { c } );
  _cells = _cells.map(c => if (c.wrap) { 
    let first = c; 
    let second = c;

    first.size = row_width - calc.rem(c.start, row_width)
    second.size = c.size - first.size
    
    return (first, second)
  } else { c }).flatten()
  cells = _cells.map(c => bfcell(int(c.size),fill:c.fill, height: rowheight * c.multirow)[#c.content])

  // calculate cells
  let current_offset = 0;
  let computed_offsets = ();
  for (idx, field) in fields.pos().enumerate() {
    let (size, content, fill, ..) = field;
    let remaining_cols = bits - col_count;
    // if no size was specified
    if (size == auto) { size = remaining_cols }
    col_count = calc.rem(col_count + size, bits);
    
    if size == none {
      size = remaining_cols
      content = content + sym.star
    }

    computed_offsets.push(if (bitheader == "smart-firstline") { current_offset } else { calc.rem(current_offset,bits) } );
    current_offset += size;
    
    // if size > bits and remaining_cols == bits and calc.rem(size, bits) == 0 {
    //   content = content + " (" + str(size) + " Bit)"
    //   cells.push(bfcell(int(bits),fill:fill, height: rowheight * size/bits)[#content])
    //   size = 0
    // }

    // while size > 0 {
    //   let width = calc.min(size, remaining_cols);
    //   size -= remaining_cols
    //   remaining_cols = bits
    //   cells.push(bfcell(int(width),fill:fill, height: rowheight,)[#content])
    // }
  
  }
  
  computed_offsets.push(bits - 1);

  let bitheader_font_size = 9pt;
  let bh_num_text(num) = {
    let alignment = if (bitheader == "all") {center} 
    else {
      if (msb_first) {
        if (num == 0) {end} else if (num == (bits - 1)) { start } else { center }
      } else { 
        if (num == (bits - 1)) {end} else if (num == 0) { start } else { center }
      }
    }

    align(alignment, text(bitheader_font_size)[#num]);
  }


  let _bitheader = if ( bitheader == "all" ) {
    // Show all numbers from 0 to total bits.
    range(bits).map(i => bh_num_text(i))
  } else if ( bitheader == "smart" or bitheader == "smart-firstline") {
    // Show nums aligned with given fields
    if msb_first == true {
      computed_offsets = computed_offsets.map(i => bits - i - 1);
    }
    range(bits).map(i => if i in computed_offsets { bh_num_text(i) } else {none})
  } else if ( type(bitheader) == array ) {
    // show given numbers from array
    range(bits).map(i => if i in bitheader { bh_num_text(i) } else {none})
  } else if ( type(bitheader) == int ) {
    // if an int is given show all multiples of this number
    let val = bitheader;
    range(bits).map(i =>
      if calc.rem(i,val) == 0 or i == (bits - 1) { bh_num_text(i) } 
      else { none })
  } else if ( bitheader == none ) {
    range(bits).map(_ => []);
  } else if (type(bitheader) == dictionary) {
    range(bits).map(i => [
      #set align(start + bottom)
      #let h_text = bitheader.at(str(i),default: "");
      #style(styles => {
        let size = measure(h_text, styles).width
        return box(height: size, inset:(left: 50%))[
          
          #if (h_text != "" and bitheader.at("marker", default: auto) != none){ place(bottom, line(end:(0pt, 5pt))) }
          #rotate(bitheader.at("angle", default: -60deg), origin: left, h_text)
        ]  
      })
    ])
  } else {
     panic("bitheader must be an integer,array, none, 'all' or 'smart'")
  }

  // revers bit order
  if msb_first == true {
    _bitheader = _bitheader.rev()
  }
  
  box(width: 100%)[
    #gridx(
      columns: range(bits).map(i => 1fr),
      align: center + horizon,
      inset: (x:0pt, y: 4pt),
      .._bitheader,
      ..cells,
    )
  ]
}

// Low level API
#let bitbox(length_in_bits, content, fill: none) = (
  type: "bitbox",
  size: length_in_bits,   // length of the field 
  fill: fill,
  content: content,
  var: false, 
  show_size: false,
)

// High level API
#let bit(..args) = bitbox(1, ..args)
#let bits(len, ..args) = bitbox(len, ..args)
#let byte(..args) = bitbox(8, ..args)
#let bytes(len, ..args) = bitbox(len * 8, ..args)
#let padding(..args) = bitbox(auto, ..args)

// Rotating text for flags
#let flagtext(text) = align(center,rotate(270deg,text))
