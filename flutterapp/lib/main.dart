import 'dart:ui';

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        fontFamily: 'RobotoMono',
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          titleLarge: TextStyle(color: Colors.white),
          labelLarge: TextStyle(color: Colors.white),
        ),
      ),
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Color.fromRGBO(173,100,99, 1), 
          // Change background color
          title: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.0), // Add padding around the title
            child: Text(
              '<>          AI Hallucination Pipeline for Binfin8 Onboarding - Omar Shatat          <>',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/cyberbackground.png', // replace with your image path
                fit: BoxFit.cover,
                color: Colors.black.withOpacity(0.4), // optional overlay to darken image
                colorBlendMode: BlendMode.darken,
              ),
            ),
            FlaskTestWidget(), // your existing content on top
          ],
        ),
      ),
    );
  }
}

class FlaskTestWidget extends StatefulWidget {
  @override
  _FlaskTestWidgetState createState() => _FlaskTestWidgetState();
}

class _FlaskTestWidgetState extends State<FlaskTestWidget> {
  final TextEditingController _controller = TextEditingController();

  String _openaiResponse = '';
  String _togetherResponse = '';
  String _openaiHallucination = '';
  String _togetherHallucination = '';
  String _openaiImprovedQuery = '';
  String _openaiUpdatedResponse = '';
  int _openaiWordCount = 0;
  int _togetherWordCount = 0;

  double _openaiScore = 0.0;
  double _togetherScore = 0.0;

  int _latencyMs = 0;

  double _openaiUpdatedScore = 0.0;
  int _openaiUpdatedWordCount = 0;
  int _openaiUpdatedLatencyMs = 0;

  List<dynamic> _openaiSpans = [];
  List<dynamic> _togetherSpans = [];

  Future<void> _sendToFlask() async {
    final url = Uri.parse('http://localhost:5000/query');
    final prompt = _controller.text;

    try {
      final stopwatch = Stopwatch()..start();
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'input': prompt}),
      );
      stopwatch.stop();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          _openaiResponse = data['openai'] ?? '';
          _togetherResponse = data['together'] ?? '';

          _latencyMs = stopwatch.elapsedMilliseconds;

          _openaiWordCount = _openaiResponse.split(RegExp(r'\s+')).length;
          _togetherWordCount = _togetherResponse.split(RegExp(r'\s+')).length;

          _openaiScore = (data['hallucination_openai']['score'] as num).toDouble();
          _openaiHallucination = '${data['hallucination_openai']['label']} (score: $_openaiScore)';
          _togetherScore = (data['hallucination_together']['score'] as num).toDouble();
          _togetherHallucination = '${data['hallucination_together']['label']} (score: $_togetherScore)';

          _openaiImprovedQuery = '';
          _openaiUpdatedResponse = '';
          _openaiUpdatedScore = 0.0;
          _openaiUpdatedWordCount = 0;
          _openaiUpdatedLatencyMs = 0;

          _openaiSpans = data['hallucination_spans_openai'] ?? [];
          _togetherSpans = data['hallucination_spans_together'] ?? [];
        });
      }
    } catch (e) {
      setState(() {
        _openaiResponse = 'Failed to connect to Flask: $e';
        _togetherResponse = '';
      });
    }
  }

  Future<void> _generateImprovedQuery() async {
    final url = Uri.parse('http://localhost:5000/improve_query');
    final prompt = _controller.text;
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'input': prompt}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _openaiImprovedQuery = data['improved_query'] ?? '';
      });
    }
  }

  Future<void> _getUpdatedResponse() async {
    final url = Uri.parse('http://localhost:5000/query');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'input': _openaiImprovedQuery}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final stopwatch = Stopwatch()..start();

      setState(() {
        _openaiUpdatedResponse = data['openai'] ?? '';
        _openaiUpdatedWordCount = _openaiUpdatedResponse.split(RegExp(r'\s+')).length;
        _openaiUpdatedScore = (data['hallucination_openai']['score'] as num).toDouble();
        _openaiUpdatedLatencyMs = stopwatch.elapsedMilliseconds;
      });
    }
  }

_buildLabeledChart(String label, double value, {required double maxY}) {
  return Column(
    children: [
      SizedBox(
        width: 100,
        height: 140, // fixed chart height
        child: BarChart(
          BarChartData(
            maxY: maxY,
            barGroups: [
              BarChartGroupData(x: 0, barRods: [
                BarChartRodData(
                  toY: value.clamp(0, maxY), // clamp value to avoid overflow
                  width: 40,
                  color: Color.fromRGBO(0, 247, 255, .9),
                  borderRadius: BorderRadius.zero, // square corners
                ),
              ]),
            ],
            titlesData: FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(show: false),
          ),
        ),
      ),
      SizedBox(height: 8),
      Column(
        children: [
          Text('$label:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(value.toStringAsFixed(2), style: TextStyle(fontSize: 16)),
        ],
      ),
    ],
  );
}



@override
Widget build(BuildContext context) {
  return SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 50),
        Center(
        child: Container(
              child: Column(
                children: [
                  Container(
                    width: 900,
                    child: Text(
                      "<>      What is AI Hallucination?      <>",
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color.fromRGBO(33, 248, 255, 1)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 20),
                  Container(
                    width: 900,
                    child: Text(
                      "You’ve exhausted ChatGPT. Question after question goes by, until suddenly, you take the time to read the response that it returns. As you are reading the response, you recall your class lesson that day. “That doesn’t seem right. Hold on!” You scroll up to view previous responses, and you notice that ChatGPT got key facts wrong! In terms of large language models like ChatGPT, this is known as a phenomenon called “AI hallucination”, where the LLM generates responses that are either nonsensical, fabricated, or just straight out factually incorrect. This page gives you a chance to explore an AI hallucination pipeline, where you start off with a query, and explore different aspects of hallucination, and ways to reduce that hallucination as a whole! Enter your query below!",
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w300),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
          ),
        ),

        SizedBox(height: 100),
        
        Center(
        child: Column(
          children: [
            Text (
                "Enter your query and begin the pipeline!",
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            Container(
              width: 800,
              padding: EdgeInsets.only(top: 40),
              child: TextField(
                controller: _controller,
                maxLines: null,
                minLines: 1,
                style: TextStyle(color: Colors.black), // <-- This sets typed text color
                decoration: InputDecoration(
                  labelText: 'Enter a prompt',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 20), 
              child: SizedBox(
                width: 200,
                height: 50,
                child: ElevatedButton(
                  onPressed: _sendToFlask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromRGBO(173, 100, 99, 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text('Submit prompt', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
        ),
        Center(
          child: Padding(
            padding: EdgeInsets.only(top: 20, bottom: 20), 
            child: Image.asset(
                      'assets/images/whitearrow.png',
                      width: 100,
                      height: 100,
            ),
          ),
        ),


        Center (
          child: Container (
            width: 1300,
            decoration: BoxDecoration(
              color: Color.fromRGBO(31,29,77,.6), // background color
              borderRadius: BorderRadius.circular(0), // optional rounded corners
            ),
            child: Column( 
              children: [ 
                Padding (
                  padding: EdgeInsets.only(top: 20, bottom: 20),
                  child: Text(
                    "Let's assess the hallucination score for OpenAI!",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    )
                  )
                ),
                Divider(
                  color: Colors.white,    // line color
                  thickness: 2,          // line thickness
                  indent: 100,            // start padding
                  endIndent: 100,         // end padding
                ),
                Padding (
                  padding: EdgeInsets.only(top: 20),
                  child: Container(
                    width: 700,
                    child: Text(
                      textAlign: TextAlign.center,
                      "Here is the result from the prompt you gave OpenAI, and below that response, is the same response with hallucination span detection, highlighted green meaning that it is likely not hallucinated, and highlighted red meaning it is likely hallucinated",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                      )
                    )
                  ),
                ),
                Padding (
                  padding: EdgeInsets.only(top: 60),
                  child: Container (
                    width: 800,
                    child: Text(
                      _openaiResponse,
                      style: TextStyle(
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 40, bottom: 40),
                  child: Container (
                    width: 800,
                    child: RichText(
                      text: TextSpan(
                      children: _buildHighlightedSpans(_openaiResponse, _openaiSpans),
                      style: TextStyle(fontSize: 16, fontFamily: "RobotoMono"),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Divider(
                  color: Colors.white,    // line color
                  thickness: 2,          // line thickness
                  indent: 100,            // start padding
                  endIndent: 100,         // end padding
                ),
                Padding (
                  padding: EdgeInsets.only(top: 30, bottom: 20),
                  child: Container(
                    width: 900,
                    child: Text(
                      textAlign: TextAlign.center,
                      "Below are some hallucination metrics for the OpenAI response. From left to right, you can see the hallucination level, 1 indicating it is hallucinated, and 0 indicating it is not likely hallucinated, the word count of the responses the LLM gave us, and the latency in miliseconds. Interact with the graphs!",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                      )
                    )
                  ),
                ),
                Padding (
                  padding: EdgeInsets.only(top: 60, bottom: 20),
                  child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildLabeledChart('Hallucination', _openaiScore, maxY: 1.0),
                    _buildLabeledChart('Word Count', _openaiWordCount.toDouble(), maxY: 150),
                    _buildLabeledChart('Latency (ms)', _latencyMs.toDouble(), maxY: 3000),
                  ],
                ),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 30),

        Center (
          child: Image.asset(
            'assets/images/whitearrow.png',
            width: 100,
            height: 100,
          ),
        ),

        Center (
          child: Container (
            width: 800,
            child: Text(
              textAlign: TextAlign.center,
              "Now what happens if we change the LLM, or perhaps the way we retreive the information. This next section will show how an LLM from Meta will compare in terms of hallucination, when we use RAG, retreival-augmented generation, to enhance our prompt and feed the LLM external data from Wikipedia to reduce hallucination. Let's find out if it works!",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        Center (
          child: Image.asset(
            'assets/images/whitearrow.png',
            width: 100,
            height: 100,
          ),
        ),

        Center (
          child: Container (
            width: 1300,
            decoration: BoxDecoration(
              color: Color.fromRGBO(31,29,77,.6), // background color
              borderRadius: BorderRadius.circular(0), // optional rounded corners
            ),
            child: Column( 
              children: [ 
                Padding (
                  padding: EdgeInsets.only(top: 20, bottom: 20),
                  child: Text(
                    "Let's assess the hallucination score for the Meta LLM + Wikipedia API RAG!",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    )
                  )
                ),
                Divider(
                  color: Colors.white,    // line color
                  thickness: 2,          // line thickness
                  indent: 100,            // start padding
                  endIndent: 100,         // end padding
                ),
                Padding (
                  padding: EdgeInsets.only(top: 20),
                  child: Container(
                    width: 700,
                    child: Text(
                      textAlign: TextAlign.center,
                      "Here is the response from the prompt you gave Meta LLM + RAG Wikipedia context, and below that, is the same response with hallucination span detection, highlighted green meaning that it is likely not hallucinated, and highlighted red meaning it is likely hallucinated",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                      )
                    )
                  ),
                ),
                Padding (
                  padding: EdgeInsets.only(top: 60),
                  child: Container (
                    width: 800,
                    child: Text(
                      _togetherResponse,
                      style: TextStyle(
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 40, bottom: 40),
                  child: Container (
                    width: 800,
                    child: RichText(
                      text: TextSpan(
                      children: _buildHighlightedSpans(_togetherResponse, _togetherSpans),
                      style: TextStyle(fontSize: 16, fontFamily: "RobotoMono"),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Divider(
                  color: Colors.white,    // line color
                  thickness: 2,          // line thickness
                  indent: 100,            // start padding
                  endIndent: 100,         // end padding
                ),
                Padding (
                  padding: EdgeInsets.only(top: 30, bottom: 20),
                  child: Container(
                    width: 900,
                    child: Text(
                      textAlign: TextAlign.center,
                      "Below are some hallucination metrics for the Meta + RAG response. From left to right, you can see the hallucination level, 1 indicating it is hallucinated, and 0 indicating it is not likely hallucinated, the word count of the responses the LLM gave us, and the latency in miliseconds. Interact with the graphs!",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                      )
                    )
                  ),
                ),
                Padding (
                  padding: EdgeInsets.only(top: 60, bottom: 20),
                  child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildLabeledChart('Hallucination', _togetherScore, maxY: 1.0),
                    _buildLabeledChart('Word Count', _togetherWordCount.toDouble(), maxY: 150),
                    _buildLabeledChart('Latency (ms)', _latencyMs.toDouble(), maxY: 3000),
                  ],
                ),
                ),
              ],
            ),
          ),
        ),

        Center (
          child: Image.asset(
            'assets/images/whitearrow.png',
            width: 100,
            height: 100,
          ),
        ),

        Center (
          child: Container (
            width: 800,
            child: Text(
              textAlign: TextAlign.center,
              "Let us now introduce prompt engineering. What we will do now, is use OpenAI to help us produce a better prompt. By clicking the button below, you will take your original prompt, feed it to OpenAI, and return a prompt that is a lot more precise, and does its very best to reduce AI hallucination. Let us see if it helps in reducing AI hallucination",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        Center (
          child: Image.asset(
            'assets/images/whitearrow.png',
            width: 100,
            height: 100,
          ),
        ),

        Center (
          child: Container (
            width: 1300,
            decoration: BoxDecoration(
              color: Color.fromRGBO(31,29,77,.6), // background color
              borderRadius: BorderRadius.circular(0), // optional rounded corners
            ),
            child: Column( 
              children: [ 
                Padding (
                  padding: EdgeInsets.only(top: 20, bottom: 30),
                  child: Text(
                    "Let's see the new prompt OpenAI can provide us",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(
                  width: 300,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _generateImprovedQuery,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromRGBO(173, 100, 99, 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text('Create better query', style: TextStyle(fontSize: 20, color: Colors.white)),
                  ),
                ),
                SizedBox(height: 20),
                Divider(
                  color: Colors.white,    // line color
                  thickness: 2,          // line thickness
                  indent: 100,            // start padding
                  endIndent: 100,         // end padding
                ),
                Padding (
                  padding: EdgeInsets.only(top: 20),
                  child: Container(
                    width: 700,
                    child: Text(
                      textAlign: TextAlign.center,
                      "Below is our new prompt using prompt engineering, adding things like supporting documents, double-checking facts, and really aiming to reduce the hallucination levels.",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      )
                    )
                  ),
                ),
                Padding (
                  padding: EdgeInsets.only(top: 60, bottom: 40),
                  child: Container (
                    width: 800,
                    child: Text(
                      _openaiImprovedQuery,
                      style: TextStyle(
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  ),
                ),
              ],
            ),
          ),
        ),

        Center (
          child: Image.asset(
            'assets/images/whitearrow.png',
            width: 100,
            height: 100,
          ),
        ),

        Center (
          child: Container (
            width: 800,
            child: Text(
              textAlign: TextAlign.center,
              "Click the button below to see the updated prompt's response from OpenAI, and its corresponding hallucination metrics.",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        Center (
          child: Image.asset(
            'assets/images/whitearrow.png',
            width: 100,
            height: 100,
          ),
        ),

        Center (
          child: Container (
            width: 1300,
            decoration: BoxDecoration(
              color: Color.fromRGBO(31,29,77,.6), // background color
              borderRadius: BorderRadius.circular(0), // optional rounded corners
            ),
            child: Column( 
              children: [ 
                Padding (
                  padding: EdgeInsets.only(top: 20, bottom: 20),
                  child: Text(
                    textAlign: TextAlign.center,
                    "Let's assess the hallucination score for our new OpenAI response using a query that underwent prompt engineering.",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    )
                  )
                ),
                SizedBox(
                  width: 300,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _getUpdatedResponse,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromRGBO(173, 100, 99, 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text('Get updated response', style: TextStyle(fontSize: 20, color: Colors.white)),
                  ),
                ),
                SizedBox(height: 20),
                Divider(
                  color: Colors.white,    // line color
                  thickness: 2,          // line thickness
                  indent: 100,            // start padding
                  endIndent: 100,         // end padding
                ),
                Padding (
                  padding: EdgeInsets.only(top: 20),
                  child: Container(
                    width: 700,
                    child: Text(
                      textAlign: TextAlign.center,
                      "Here is the response from the updated prompt you gave OpenAI, and below that, is the same response with hallucination span detection, highlighted green meaning that it is likely not hallucinated, and highlighted red meaning it is likely hallucinated",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                      )
                    )
                  ),
                ),
                Padding (
                  padding: EdgeInsets.only(top: 60, bottom: 20),
                  child: Container (
                    width: 800,
                    child: Text(
                      _openaiUpdatedResponse,
                      style: TextStyle(
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  ),
                ),
                Divider(
                  color: Colors.white,    // line color
                  thickness: 2,          // line thickness
                  indent: 100,            // start padding
                  endIndent: 100,         // end padding
                ),
                Padding (
                  padding: EdgeInsets.only(top: 30, bottom: 20),
                  child: Container(
                    width: 900,
                    child: Text(
                      textAlign: TextAlign.center,
                      "Below are some hallucination metrics for the updated OpenAI response. From left to right, you can see the hallucination level, 1 indicating it is hallucinated, and 0 indicating it is not likely hallucinated, the word count of the responses the LLM gave us, and the latency in miliseconds. Interact with the graphs!",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                      )
                    )
                  ),
                ),
                Padding (
                  padding: EdgeInsets.only(top: 60, bottom: 20),
                  child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildLabeledChart('Hallucination', _openaiUpdatedScore, maxY: 1.0),
                    _buildLabeledChart('Word Count', _openaiUpdatedWordCount.toDouble(), maxY: 150),
                    _buildLabeledChart('Latency (ms)', _openaiUpdatedLatencyMs.toDouble(), maxY: 3000),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        Center (
          child: Image.asset(
            'assets/images/whitearrow.png',
            width: 100,
            height: 100,
          ),
        ),

        Center (
          child: Container (
            width: 800,
            child: Text(
              textAlign: TextAlign.center,
              "Thank you for going down the AI hallucination pipeline. We were able to see AI hallucination metrics like the latency, word count, and hallucination levels of different types of LLM and RAG combinations. To restart with a different prompt, refresh the page, and go down the pipeline again!",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        Center (
          child: Image.asset(
            'assets/images/whitearrow.png',
            width: 100,
            height: 100,
          ),
        ),

        Center (
          child: Container (
            width: 800,
            child: Text(
              textAlign: TextAlign.center,
              "Thank you so much for viewing this project! \n LinkedIn: https://www.linkedin.com/in/omar-shatat-9506a4356/ \n Github: https://github.com/OmarCoderBro",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(height: 200),

      ],
    ),
  );
}


  List<TextSpan> _buildHighlightedSpans(String response, List<dynamic> spans) {
    spans.sort((a, b) => a['start'].compareTo(b['start']));
    List<TextSpan> result = [];

    int currentIndex = 0;
    for (var span in spans) {
      int start = span['start'];
      int end = span['end'];

      // Add normal text before this span
      if (start > currentIndex) {
        result.add(TextSpan(
          text: response.substring(currentIndex, start),
          style: TextStyle(backgroundColor: Colors.green, color: Colors.black),
        ));
      }

      // Add highlighted hallucinated span
      result.add(TextSpan(
        text: response.substring(start, end),
        style: TextStyle(backgroundColor: Colors.redAccent, color: Colors.black),
      ));

      currentIndex = end;
    }

    // Add remaining normal text
    if (currentIndex < response.length) {
      result.add(TextSpan(
        text: response.substring(currentIndex),
          style: TextStyle(backgroundColor: Colors.green, color: Colors.black),
      ));
    }

    return result;
  }
}
