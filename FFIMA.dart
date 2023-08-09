// ignore_for_file: non_constant_identifier_names, avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:core';
import 'dart:math';

import 'package:csv/csv.dart';

const debug = false;
// Mass error
const double eps = 10e-6;

void main() async {
  const file1 = 'T-AKO.csv'; // Theoratical MS1&MS2.csv file
  const file2 = 'AKO-1.csv'; // Measured MS1&MS2.csv file
  final table1 = (await File(file1)
          .openRead()
          .transform(utf8.decoder)
          .transform(const CsvToListConverter())
          .toList())
      .sublist(1);

  final table2 = (await File(file2)
          .openRead()
          .transform(utf8.decoder)
          .transform(const CsvToListConverter())
          .toList())
      .sublist(1);

  var results = <Result>[];

  for (final a_s in table1) {

    final a = Data(a_s[0], a_s[1]);
    final a_x = [
      Data(1, a_s[2]), // a1-theoretical feature fragments 1
      Data(2, a_s[3]), // a2-theoretical feature fragments 2
      Data(3, a_s[4]), // a3-theoretical feature fragments 3
    ];

    printDebug("${a.no} Start. =>");
    for (final b_s in table2) {
      final b = Data(b_s[0], b_s[1]);
      printDebug("  a[$a] -> b[$b]: ${calculate(a.value, b.value)}");
      if (judge(a.value, b.value)) {

        var fulfilledB = <Data>[];
        for (final A in a_x) {
          var findedB = false;
          var index = 2;

          while (b_s[index + 1].toString().isNotEmpty) {
          
            final B = Data(b_s[index + 1], b_s[index]);
            printDebug("    A[$A] -> B[$B]: ${calculate(A.value, B.value)}");
            if (judge(A.value, B.value)) {
              if (debug) {
                printDebug("      $A -> $B Matched.");
              }
              findedB = true;
              fulfilledB.add(B);
              break;
            }
            index += 2;
            if (index >= b_s.length) {
              break;
            }
          }
          if (!findedB) {
            break;
          }
        }

        if (fulfilledB.length == 3) {

          results.add(
            Result(a.no, b.no, fulfilledB[0], fulfilledB[1], fulfilledB[2]),
          );
          break;
        }
      }
    }

    printDebug("${a.no} Complete. <=");
  }

  // Output Original matched results
  print("Origin Results (${results.length}):");
  for (final result in results) {
    print("$result");
  }

  // Results filtering
  print("Filtering...");
  final filteredResults = results
      .where(
        (result) => filterResult(table1, table2, result),
      )
      .toList();

  print("Filtered Results (${filteredResults.length}):");
  for (final result in filteredResults) {
    print("$result");
  }
}


class Data {
  final int no;
  final double value;

  Data(this.no, this.value);

  @override
  String toString() {
    return "$no -> $value";
  }

  @override
  bool operator ==(Object other) {
    if (other is Data) {
      return no == other.no
          &&
          value == other.value;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(no, value);
}

class Result {
  final int a_No;
  final int b_No;
  final Data b1;
  final Data b2;
  final Data b3;

  Result(this.a_No, this.b_No, this.b1, this.b2, this.b3);

  @override
  String toString() {
    return "$a_No -> $b_No: (b1:[$b1], b2:[$b2], b3:[$b3])";
  }
}

bool judge(double a, double b) {
  return calculate(a, b).abs() < eps;
}

double calculate(double a, double b) {
  return ((a - b) / a);
}

void printDebug(String msg) {
  if (debug) {
    print(msg);
  }
}


int? findMaxDuplicatedNumber(List<Data> sortedList) {
  
  for (final data in sortedList) {
    
    if (sortedList
            .where(
              (e) => (data.no - 1 <= e.no && e.no <= data.no + 1),
            )
            .length >=
        3) return data.no;
  }
  return null;
}

bool filterResult(List<List> table1, List<List> table2, Result result) {

  final result_b_s = [result.b1, result.b2, result.b3];

  for (final b in result_b_s) {
    // Minimun noise filtering threshold
    if (b.no <= 21) {
      print('(failed, 1): $result');
      return false;
    }
  }


  final b_s = <Data>[];
  for (var i = 2; i < table2[result.b_No - 1].length; i += 2) {
    if (table2[result.b_No - 1][i + 1].toString().isEmpty) break;
    b_s.add(Data(table2[result.b_No - 1][i + 1], table2[result.b_No - 1][i]));
  }
  
  b_s.sort((a, b) {
    final noCompare = b.no.compareTo(a.no);
    if (noCompare == 0) {
      return b.value.compareTo(a.value);
    } else {
      return noCompare;
    }
  });

  final maxDuplicatedNumber = findMaxDuplicatedNumber(b_s);
  
  if (maxDuplicatedNumber == null) {
    print('(failed, 2*): $result');
    return false;
  }

  for (final b_no in result_b_s) {
  
    if (b_no.no <= maxDuplicatedNumber) {
      print('(failed, 2 -> $maxDuplicatedNumber): $result');
      return false;
    }
  }

  
  final filtered_b_s = b_s
      .where(
        (e) => (100 < e.value && e.value < 700),
      )
      .toList();

  // Response intensity ranking
  final condition3 = filtered_b_s.indexWhere((e) => e.no == result.b1.no) + 1;
  if (condition3 > 10) {
    print('(failed, 3 -> $condition3): $result');
    return false;
  }


  final bigger = max(result.b2.no, result.b3.no);
  final smaller = min(result.b2.no, result.b3.no);
  final condition4_1 = filtered_b_s.indexWhere((e) => e.no == bigger) + 1;
  final condition4_2 = filtered_b_s.indexWhere((e) => e.no == smaller) + 1;
  if (condition4_1 > 6 || condition4_2 > 8) {
    print('(failed, 4 -> $condition4_1, $condition4_2): $result');
    return false;
  }

  return true;
}
