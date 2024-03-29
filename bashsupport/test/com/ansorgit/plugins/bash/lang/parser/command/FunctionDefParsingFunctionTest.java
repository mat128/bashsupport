/*
 * Copyright 2010 Joachim Ansorg, mail@ansorg-it.com
 * File: FunctionDefParsingFunctionTest.java, Class: FunctionDefParsingFunctionTest
 * Last modified: 2010-05-27
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.ansorgit.plugins.bash.lang.parser.command;

import com.ansorgit.plugins.bash.lang.parser.BashPsiBuilder;
import com.ansorgit.plugins.bash.lang.parser.MockPsiTest;
import com.ansorgit.plugins.bash.lang.parser.Parsing;
import org.junit.Test;

public class FunctionDefParsingFunctionTest extends MockPsiTest {
    MockFunction f = new MockFunction() {
        @Override
        public boolean apply(BashPsiBuilder psi) {
            return Parsing.command.parse(psi);
        }
    };

    @Test
    public void testFunctionDefError() throws Exception {
        //function a b {
        //echo
        //}
        mockTestError(f, FUNCTION_KEYWORD, WHITESPACE, WORD, WHITESPACE, WORD, LEFT_CURLY, LINE_FEED, WORD, LINE_FEED, RIGHT_CURLY);
    }
}
